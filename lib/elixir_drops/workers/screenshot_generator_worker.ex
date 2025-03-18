defmodule ElixirDrops.Workers.ScreenshotGeneratorWorker do
  @moduledoc false

  use Oban.Worker, queue: :seo_images, max_attempts: 5
  use ElixirDropsWeb, :verified_routes

  alias ElixirDrops.Drops
  alias ElixirDrops.S3Helper.Client
  alias ElixirDrops.ScreenshotGenerator
  alias Wallaby.Browser

  @markdown_regex ~r/```(?:\w+\n)?(.+?)```/s

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
    with {:ok, drop} <- get_drop(args["drop_id"]),
         {:ok, _code_block} <- check_for_code_block(drop.body) do
      drop_screenshot(drop)
    else
      _error ->
        {:cancel, "No code block found"}
    end
  end

  defp drop_screenshot(drop) do
    FLAME.call(ScreenshotGenerator, fn ->
      with {:ok, screenshots} <- generate_screenshot(drop),
           {:ok, meta_image} <- File.read(screenshots.meta),
           {:ok, internal_image} <- File.read(screenshots.internal) do
        upload_screenshots(%{meta: meta_image, internal: internal_image}, drop)
      end
    end)
  end

  defp get_drop(id) do
    case Drops.get_drop(%{drop_id: id}) do
      nil -> {:error, "Drop not found"}
      drop -> {:ok, drop}
    end
  end

  @spec check_for_code_block(binary()) :: {:ok, String.t()} | {:error, String.t()}
  def check_for_code_block(body) do
    case Regex.run(@markdown_regex, body, capture: :first) do
      nil -> {:error, "No code block found"}
      [code_block] -> {:ok, code_block}
    end
  end

  defp generate_screenshot(drop) do
    # Meta screenshot
    {:ok, session_meta} =
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

    url_meta = build_url_with_auth(drop, :meta)

    %Wallaby.Session{screenshots: [meta_screenshot]} =
      session_meta
      |> Browser.visit(url_meta)
      |> Browser.take_screenshot()

    Wallaby.end_session(session_meta)

    # Internal screenshot
    {:ok, session_internal} =
      Wallaby.start_session(
        capabilities: %{
          chromeOptions: %{
            args: [
              "--headless",
              "--no-sandbox",
              "--disable-gpu",
              "--fullscreen",
              "--disable-dev-shm-usage"
            ]
          }
        }
      )

    code_block_size =
      case check_for_code_block(drop.body) do
        {:ok, code_block} ->
          lines = length(String.split(code_block, ~r/\n/))
          min_height = 100
          line_height = 30
          raw_size = line_height * lines
          size = max(min_height, raw_size) |> min(1100)
          round(size / 50) * 50

        {:error, "No code block found"} ->
          0
      end

    url_internal = build_url_with_auth(drop, :internal)
    resized_window_session = Browser.resize_window(session_internal, 900, code_block_size)
    new_session = Browser.visit(resized_window_session, url_internal)

    %Wallaby.Session{screenshots: [internal_screenshot]} = Browser.take_screenshot(new_session)
    Wallaby.end_session(new_session)

    {:ok, %{meta: meta_screenshot, internal: internal_screenshot}}
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

  defp upload_screenshots(images, drop) do
    timestamp = Timex.to_unix(drop.updated_at)
    meta_image_name = image_name(:meta, drop.id, timestamp)

    case Client.upload_image(images.meta, meta_image_name, "image/png") do
      {:ok, meta_url} ->
        internal_image_name = image_name(:internal, drop.id, timestamp)

        case Client.upload_image(images.internal, internal_image_name, "image/png") do
          {:ok, internal_url} ->
            {:ok, %{meta: meta_url, internal: internal_url}}

          error ->
            error
        end

      error ->
        error
    end
  end

  defp image_name(:meta, drop_id, timestamp), do: "drop-meta-image-#{timestamp}-#{drop_id}.png"

  defp image_name(_type, drop_id, timestamp),
    do: "drop-internal-image-#{timestamp}-#{drop_id}.png"
end
