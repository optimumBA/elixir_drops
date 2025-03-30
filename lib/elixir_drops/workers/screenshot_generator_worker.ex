defmodule ElixirDrops.Workers.ScreenshotGeneratorWorker do
  @moduledoc false

  use Oban.Worker, queue: :seo_images, max_attempts: 5
  use ElixirDropsWeb, :verified_routes

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.DropsBroadcast
  alias ElixirDrops.S3Helper.Client
  alias ElixirDrops.ScreenshotGenerator
  alias Wallaby.Browser

  @markdown_regex ~r/```(?:\w+\n)?(.+?)```/s

  # Stages of the screenshot process with their respective percentage values
  @stages %{
    started: 5,
    drop_found: 10,
    code_block_verified: 15,
    session_started: 25,
    screenshot_taken: 50,
    processing_image: 70,
    uploading: 85,
    # Leave the completed status at 95% to avoid showing 100% before the URL is actually available
    ready_for_preview: 95
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
    # broadcast_drop_screenshot_progress(nil, @stages.started, :generating)

    with {:ok, drop} <- get_drop(args["drop_id"]),
         :ok <- check_for_code_block(drop) do
      drop_screenshot(drop)
    else
      _error ->
        {:cancel, "No code block found"}
    end
  end

  defp drop_screenshot(drop) do
    FLAME.call(ScreenshotGenerator, fn ->
      with {:ok, screenshot} <- generate_screenshot(drop),
           {:ok, image} <- File.read(screenshot) do
        broadcast_drop_screenshot_progress(drop, @stages.processing_image, :generating)

        upload_screenshot(image, drop)
      end
    end)
  end

  defp get_drop(id) do
    case Drops.get_drop(%{drop_id: id}) do
      nil ->
        {:error, "Drop not found"}

      drop ->
        broadcast_drop_screenshot_progress(drop, @stages.drop_found, :generating)
        {:ok, drop}
    end
  end

  defp check_for_code_block(drop) do
    case Regex.run(@markdown_regex, drop.body, capture: :first) do
      nil ->
        {:error, "No code block found"}

      _code_block ->
        broadcast_drop_screenshot_progress(drop, @stages.code_block_verified, :generating)
        :ok
    end
  end

  defp generate_screenshot(drop) do
    broadcast_drop_screenshot_progress(drop, @stages.code_block_verified, :generating)

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

    broadcast_drop_screenshot_progress(drop, @stages.session_started, :generating)

    url = build_url_with_auth(drop)

    %Wallaby.Session{screenshots: [screenshot]} =
      session
      |> Browser.visit(url)
      |> Browser.take_screenshot()

    Wallaby.end_session(session)

    broadcast_drop_screenshot_progress(drop, @stages.screenshot_taken, :generating)

    {:ok, screenshot}
  end

  defp build_url_with_auth(drop) do
    [username: username, password: password] = Application.get_env(:elixir_drops, :wallaby_auth)

    url = url(~p"/d/#{drop.id}/code_snippet")

    [scheme, rest] = String.split(url, "//", parts: 2)

    "#{scheme}//#{username}:#{password}@#{rest}"
  end

  defp upload_screenshot(screenshot, drop) do
    broadcast_drop_screenshot_progress(drop, @stages.uploading, :generating)

    timestamp = Timex.to_unix(drop.updated_at)

    image_name = "drop-meta-image-#{timestamp}-#{drop.id}.png"

    case Client.upload_image(screenshot, image_name, "image/png") do
      {:ok, image_url} ->
        drop = Map.put(drop, :screenshot_url, image_url)

        # Set to ready_for_preview (95%) instead of 100% to indicate that the image
        # is available but waiting for user confirmation
        broadcast_drop_screenshot_progress(drop, @stages.ready_for_preview, :completed)

        {:ok, image_url}

      error ->
        error
    end
  end

  defp broadcast_drop_screenshot_progress(drop, progress, status) do
    DropsBroadcast.broadcast_drop_screenshot_progress(drop, progress, status)
  end
end
