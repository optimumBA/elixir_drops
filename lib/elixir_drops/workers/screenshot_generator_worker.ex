defmodule ElixirDrops.Workers.ScreenshotGeneratorWorker do
  @moduledoc false

  use Oban.Worker, queue: :seo_images, max_attempts: 5
  use ElixirDropsWeb, :verified_routes

  alias ElixirDrops.Drops
  alias ElixirDrops.S3Helper.Client
  alias ElixirDrops.ScreenshotGenerator
  alias ElixirDrops.ScreenshotGeneratorWorkerHelper
  alias Wallaby.Browser

  @code_block_pattern ~r/```(?:\w+\n)?(.+?)```/s

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    case args["action"] do
      "edit" -> handle_edit(args)
      _new -> handle_new(args)
    end
  end

  defp handle_edit(args) do
    with {:ok, drop} <- get_drop(args["drop_id"]),
         {:ok, old_code_snippet} <-
           check_for_code_block(args["old_body"]),
         {:ok, new_code_snippet} <-
           check_for_code_block(drop.body),
         :ok <-
           compare_code_blocks(old_code_snippet, new_code_snippet) do
      drop_screenshots(drop)
    else
      {:cancel, _reason} ->
        {:cancel, "Code block unchanged"}

      _error ->
        {:cancel, "No code block found"}
    end
  end

  defp handle_new(args) do
    with {:ok, drop} <- get_drop(args["drop_id"]),
         {:ok, _code_snippet} <- check_for_code_block(drop.body) do
      drop_screenshots(drop)
    else
      _error -> {:cancel, "No code block found"}
    end
  end

  defp get_drop(id) do
    case Drops.get_drop(%{drop_id: id}) do
      nil -> {:error, "Drop not found"}
      drop -> {:ok, drop}
    end
  end

  defp drop_screenshots(drop) do
    FLAME.call(ScreenshotGenerator, fn ->
      with {:ok, screenshots} <- generate_screenshots(drop),
           {:ok, meta_image} <- File.read(screenshots.meta),
           {:ok, internal_image} <- File.read(screenshots.internal) do
        upload_screenshots(%{meta: meta_image, internal: internal_image}, drop)
      end
    end)
  end

  defp check_for_code_block(body) do
    case Regex.run(@code_block_pattern, body, capture: :first) do
      nil -> {:error, "No code block found"}
      [code_block] -> {:ok, code_block}
    end
  end

  defp compare_code_blocks(old, new) when old != new, do: :ok
  defp compare_code_blocks(_old, _new), do: {:cancel, "Code block unchanged"}

  defp generate_screenshots(drop) do
    with {:ok, meta_screenshot} <- generate_meta_screenshot(drop),
         {:ok, internal_screenshot} <- generate_internal_screenshot(drop) do
      {:ok, %{meta: meta_screenshot, internal: internal_screenshot}}
    end
  end

  defp generate_meta_screenshot(drop) do
    height = ScreenshotGeneratorWorkerHelper.calc_height(drop.body)

    {:ok, session} =
      Wallaby.start_session(
        capabilities: %{
          chromeOptions: %{
            args: [
              "--headless",
              "--no-sandbox",
              "window-size=1280,#{height}",
              "--fullscreen",
              "--disable-gpu",
              "--disable-dev-shm-usage"
            ]
          }
        }
      )

    url = build_url_with_auth(drop, :meta)

    %Wallaby.Session{screenshots: [screenshot]} =
      session
      |> Browser.visit(url)
      |> Browser.take_screenshot()

    Wallaby.end_session(session)

    {:ok, screenshot}
  end

  defp generate_internal_screenshot(drop) do
    with {:ok, session} <- start_wallaby_session(),
         url <- build_url_with_auth(drop, :internal),
         resized_session <- resize_window(session, drop),
         {:ok, screenshot} <- take_screenshot(resized_session, url) do
      Wallaby.end_session(resized_session)
      {:ok, screenshot}
    end
  end

  defp start_wallaby_session do
    base_args = [
      "--headless",
      "--no-sandbox",
      "--disable-gpu",
      "--fullscreen",
      "--disable-dev-shm-usage"
    ]

    Wallaby.start_session(
      capabilities: %{
        chromeOptions: %{
          args: base_args
        }
      }
    )
  end

  defp take_screenshot(session, url) do
    session = Browser.visit(session, url)
    result = Browser.take_screenshot(session)

    case result do
      %Wallaby.Session{screenshots: [screenshot]} -> {:ok, screenshot}
      _error -> {:error, "Failed to take screenshot"}
    end
  end

  defp resize_window(session, drop) do
    code_block_size = calculate_code_block_size(drop.body)
    Browser.resize_window(session, 900, code_block_size)
  end

  defp calculate_code_block_size(body) do
    case check_for_code_block(body) do
      {:ok, code_block} ->
        lines = length(String.split(code_block, ~r/\n/))
        min_height = 120
        line_height = 35
        padding = 20
        raw_size = line_height * lines + padding
        max_height = 1100

        size =
          raw_size
          |> max(min_height)
          |> min(max_height)

        round(size / 50) * 50

      {:error, "No code block found"} ->
        0
    end
  end

  defp build_url_with_auth(drop, type) do
    [username: username, password: password] = Application.get_env(:elixir_drops, :wallaby_auth)

    url =
      case type do
        :meta -> url(~p"/d/#{drop.id}/code_snippet?type=meta")
        :internal -> url(~p"/d/#{drop.id}/code_snippet")
      end

    [scheme, rest] = String.split(url, "//", parts: 2)

    "#{scheme}//#{username}:#{password}@#{rest}"
  end

  defp upload_screenshots(screenshots, drop) do
    latest_meta_image_name = "drop-meta-image-latest-#{drop.id}.png"
    latest_internal_image_name = "drop-internal-image-latest-#{drop.id}.png"

    with {:ok, meta_image_url} <-
           Client.upload_image(screenshots.meta, latest_meta_image_name, "image/png"),
         {:ok, internal_image_url} <-
           Client.upload_image(screenshots.internal, latest_internal_image_name, "image/png") do
      screenshot_data = %{
        screenshot: %{
          meta: %{status: :completed, url: meta_image_url},
          internal: %{status: :completed, url: internal_image_url}
        }
      }

      case Drops.update_drop_screenshot(drop, screenshot_data) do
        {:ok, _updated_drop} -> :ok
        error -> error
      end
    else
      error ->
        Drops.update_drop_screenshot(drop, %{
          screenshot: %{
            meta: %{status: :failed, url: nil},
            internal: %{status: :failed, url: nil}
          }
        })

        error
    end
  end
end
