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
    with {:ok, meta_screenshot} <- generate_screenshot(drop, :meta),
         {:ok, internal_screenshot} <- generate_screenshot(drop, :internal) do
      {:ok, %{meta: meta_screenshot, internal: internal_screenshot}}
    end
  end

  defp generate_screenshot(drop, type) do
    height =
      case type do
        :meta -> ScreenshotGeneratorWorkerHelper.calc_height(drop.body)
        :internal -> ScreenshotGeneratorWorkerHelper.calc_height_internal(drop.body)
      end

    window_args =
      case type do
        :meta -> ["window-size=1280,#{height}"]
        :internal -> ["window-size=900,#{height}"]
      end

    base_args = [
      "--headless",
      "--no-sandbox",
      "--fullscreen",
      "--disable-gpu",
      "--disable-dev-shm-usage"
    ]

    {:ok, session} =
      Wallaby.start_session(
        capabilities: %{
          chromeOptions: %{
            args: window_args ++ base_args
          }
        }
      )

    url = build_url_with_auth(drop, type)

    %Wallaby.Session{screenshots: [screenshot]} =
      session
      |> Browser.visit(url)
      |> Browser.take_screenshot()

    Wallaby.end_session(session)

    {:ok, screenshot}
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

    {meta_result, updated_drop} =
      upload_and_update_screenshot(:meta, screenshots.meta, latest_meta_image_name, drop)

    {internal_result, _updated_drop} =
      upload_and_update_screenshot(
        :internal,
        screenshots.internal,
        latest_internal_image_name,
        updated_drop
      )

    case {meta_result, internal_result} do
      {:ok, :ok} ->
        :ok

      {:error, :ok} ->
        {:error, "Failed to upload meta screenshot"}

      {:ok, :error} ->
        {:error, "Failed to upload internal screenshot"}

      {:error, :error} ->
        {:error, "Failed to upload both screenshots"}
    end
  end

  defp upload_and_update_screenshot(image_type, image_data, filename, drop) do
    case Client.upload_image(image_data, filename, "image/png") do
      {:ok, image_url} ->
        {:ok,
         update_screenshot(drop, %{
           screenshot: %{image_type => %{status: :completed, url: image_url}}
         })}

      _error ->
        {:error,
         update_screenshot(drop, %{screenshot: %{image_type => %{status: :failed, url: nil}}})}
    end
  end

  defp update_screenshot(drop, screenshot_data) do
    case Drops.update_drop_screenshot(drop, screenshot_data) do
      {:ok, updated_drop} -> updated_drop
      error -> error
    end
  end
end
