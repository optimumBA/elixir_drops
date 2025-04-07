defmodule ElixirDrops.Workers.ScreenshotGeneratorWorker do
  @moduledoc false

  use Oban.Worker, queue: :seo_images, max_attempts: 5
  use ElixirDropsWeb, :verified_routes

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.DropsBroadcast
  alias ElixirDrops.S3Helper.Client
  alias ElixirDrops.ScreenshotGenerator
  alias ElixirDrops.WorkerHelpers
  alias Wallaby.Browser

  @stages %{
    initializing_flame: 20,
    creating_machine: 30,
    waiting_for_machine: 40,
    session_started: 50,
    preparing_screenshot: 65,
    screenshot_taken: 90,
    preparing_upload: 95,
    finalizing: 100
  }

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    args
    |> maybe_create_screenshot()
    |> maybe_retry_job()
  end

  defp maybe_retry_job({:ok, _image_url}), do: :ok
  defp maybe_retry_job({:cancel, reason}), do: {:cancel, reason}
  defp maybe_retry_job(error), do: error

  defp maybe_create_screenshot(args) do
    case args["action"] do
      "edit" -> handle_edit(args)
      _new -> handle_new(args)
    end
  end

  defp handle_edit(args) do
    case get_drop(args["drop_id"]) do
      {:ok, drop} ->
        case WorkerHelpers.check_for_code_block(drop.body) do
          {:ok, new_code_block} ->
            check_old_body_and_maybe_compare_code_blocks(drop, args["old_body"], new_code_block)

          {:error, _} ->
            {:cancel, "No code block found in updated drop"}
        end

      error ->
        error
    end
  end

  defp check_old_body_and_maybe_compare_code_blocks(drop, old_body, new_code_block) do
    case WorkerHelpers.check_for_code_block(old_body) do
      {:ok, old_code_snippet} ->
        case compare_code_blocks(old_code_snippet, new_code_block) do
          :ok -> drop_screenshot(drop)
          {:cancel, reason} -> {:cancel, reason}
        end

      {:error, _no_old_code_snippet} ->
        drop_screenshot(drop)
    end
  end

  defp handle_new(args) do
    with {:ok, drop} <- get_drop(args["drop_id"]),
         {:ok, _code_snippet} <- WorkerHelpers.check_for_code_block(drop.body) do
      drop_screenshot(drop)
    else
      _error -> {:cancel, "No code block found"}
    end
  end

  defp drop_screenshot(drop) do
    Task.start(fn ->
      animate_flame_startup(drop)
    end)

    FLAME.call(ScreenshotGenerator, fn ->
      with {:ok, screenshot} <- generate_screenshot(drop),
           {:ok, image} <- File.read(screenshot) do
        broadcast_drop_screenshot_progress(drop, @stages.preparing_upload, "pending")

        upload_screenshot(image, drop)
      end
    end)
  end

  defp animate_flame_startup(drop) do
    broadcast_drop_screenshot_progress(drop, @stages.initializing_flame, "pending")
    Process.sleep(300)
    broadcast_drop_screenshot_progress(drop, @stages.creating_machine, "pending")
    Process.sleep(300)
    broadcast_drop_screenshot_progress(drop, @stages.waiting_for_machine, "pending")
    Process.sleep(300)
  end

  defp get_drop(id) do
    case Drops.get_drop(%{drop_id: id}) do
      nil ->
        {:error, "Drop not found"}

      drop ->
        {:ok, drop}
    end
  end

  defp compare_code_blocks(old_body, new_body) when old_body != new_body do
    :ok
  end

  defp compare_code_blocks(_old_body, _new_body) do
    {:cancel, "Code block unchanged"}
  end

  defp generate_screenshot(drop) do
    {:ok, session} =
      Wallaby.start_session(
        capabilities: %{
          chromeOptions: %{
            args: [
              "--headless",
              "--no-sandbox",
              "window-size=1280,800",
              "--fullscreen",
              "--disable-gpu",
              "--disable-dev-shm-usage"
            ]
          }
        }
      )

    broadcast_drop_screenshot_progress(drop, @stages.session_started, "pending")

    url = build_url_with_auth(drop)

    %Wallaby.Session{screenshots: [screenshot]} =
      session
      |> Browser.visit(url)
      |> Browser.take_screenshot()

    broadcast_drop_screenshot_progress(drop, @stages.preparing_screenshot, "pending")

    Wallaby.end_session(session)

    broadcast_drop_screenshot_progress(drop, @stages.screenshot_taken, "pending")

    {:ok, screenshot}
  end

  defp build_url_with_auth(drop) do
    [username: username, password: password] = Application.get_env(:elixir_drops, :wallaby_auth)

    url = url(~p"/d/#{drop.id}/code_snippet")

    [scheme, rest] = String.split(url, "//", parts: 2)

    "#{scheme}//#{username}:#{password}@#{rest}"
  end

  defp upload_screenshot(screenshot, drop) do
    timestamp = Timex.to_unix(drop.updated_at)

    image_name = "drop-meta-image-#{timestamp}-#{drop.id}.png"

    case Client.upload_image(screenshot, image_name, "image/png") do
      {:ok, image_url} ->
        updated_drop =
          drop
          |> Map.put(:screenshot_url, image_url)
          |> Map.put(:screenshot_progress, 100)

        broadcast_drop_screenshot_progress(updated_drop, @stages.finalizing, "published")

        {:ok, image_url}

      error ->
        error
    end
  end

  defp broadcast_drop_screenshot_progress(drop, progress, status) do
    updated_drop =
      drop
      |> Map.put(:screenshot_progress, progress)
      |> Map.put(:screenshot_status, status)

    DropsBroadcast.broadcast_drop_screenshot_progress(updated_drop, progress, status)
  end
end
