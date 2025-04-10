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
    starting: 10,
    initializing_flame: 20,
    creating_machine: 30,
    waiting_for_machine: 40,
    machine_warming_up: 45,
    session_started: 50,
    preparing_screenshot: 65,
    screenshot_taken: 90,
    preparing_upload: 100,
    finalizing: 100
  }

  @flame_status_table :flame_machine_status
  @progress_interval 100

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    try do
      :ets.new(@flame_status_table, [:named_table, :set, :public])
    rescue
      _ -> :ok
    end

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
    flame_running? = is_flame_running?()

    progress_task =
      Task.async(fn ->
        simulate_continuous_progress(drop, flame_running?)
      end)

    :ets.insert(@flame_status_table, {:flame_running, true})

    result =
      FLAME.call(ScreenshotGenerator, fn ->
        with {:ok, screenshot} <- generate_screenshot(drop),
             {:ok, image} <- File.read(screenshot) do
          :ets.insert(@flame_status_table, {:progress_completed, true})
          broadcast_drop_screenshot_progress(drop, @stages.preparing_upload, "pending")

          upload_screenshot(image, drop)
        end
      end)

    :ets.insert(@flame_status_table, {:flame_running, false})
    :ets.insert(@flame_status_table, {:progress_completed, false})

    try do
      Task.await(progress_task, 10_000)
    rescue
      _ -> :ok
    end

    result
  end

  defp is_flame_running? do
    case :ets.lookup(@flame_status_table, :flame_running) do
      [{:flame_running, true}] ->
        true

      _flame_not_running ->
        false
    end
  end

  defp simulate_continuous_progress(drop, flame_already_running?) do
    if flame_already_running? do
      progress_value = @stages.machine_warming_up
      broadcast_drop_screenshot_progress(drop, progress_value, "pending")
    else
      broadcast_drop_screenshot_progress(drop, @stages.starting, "pending")

      simulate_range_progress(drop, @stages.starting, @stages.waiting_for_machine, 1500)

      Process.sleep(300)

      broadcast_drop_screenshot_progress(drop, @stages.machine_warming_up, "pending")
    end

    simulate_range_progress(drop, @stages.machine_warming_up, @stages.session_started, 800)

    simulate_range_progress(drop, @stages.session_started, @stages.preparing_screenshot, 1000)

    wait_or_continue_to_completion(drop, @stages.preparing_screenshot, @stages.screenshot_taken)
  end

  defp simulate_range_progress(drop, start_value, end_value, duration_ms) do
    step_count = div(duration_ms, @progress_interval)
    step_size = (end_value - start_value) / step_count

    Enum.reduce(1..step_count, start_value, fn step, current_value ->
      next_value = current_value + step_size

      if next_value - current_value > 0.5 do
        broadcast_drop_screenshot_progress(drop, trunc(next_value), "pending")
      end

      Process.sleep(@progress_interval)
      next_value
    end)
  end

  defp wait_or_continue_to_completion(drop, current_value, max_value) do
    case :ets.lookup(@flame_status_table, :progress_completed) do
      [{:progress_completed, true}] ->
        current_value

      _ ->
        if current_value < max_value do
          next_value = current_value + 1
          broadcast_drop_screenshot_progress(drop, next_value, "pending")
          Process.sleep(@progress_interval)
          wait_or_continue_to_completion(drop, next_value, max_value)
        else
          Process.sleep(500)
          wait_or_continue_to_completion(drop, current_value, max_value)
        end
    end
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
        screenshot_attrs = %{
          status: "published",
          url: image_url
        }

        case Drops.update_drop(drop, drop.user, %{screenshot: screenshot_attrs}) do
          {:ok, updated_drop} ->
            broadcast_drop_screenshot_progress(updated_drop, @stages.finalizing, "published")
            {:ok, image_url}

          error ->
            error
        end

      error ->
        error
    end
  end

  defp broadcast_drop_screenshot_progress(drop, progress, status) do
    screenshot_attrs =
      if drop.screenshot do
        %{
          status: status,
          url: drop.screenshot.url
        }
      else
        %{
          status: status,
          url: nil
        }
      end

    {:ok, updated_drop} = Drops.update_drop(drop, drop.user, %{screenshot: screenshot_attrs})

    DropsBroadcast.broadcast_drop_screenshot_progress(updated_drop, progress, status)
  end
end
