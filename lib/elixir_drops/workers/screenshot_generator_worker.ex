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
      with {:ok, screenshot} <- generate_screenshot(drop),
           {:ok, image} <- File.read(screenshot) do
        upload_screenshot(image, drop)
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
    {:ok, session} =
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

    url = build_url_with_auth(drop)

    code_block_size =
      case check_for_code_block(drop.body) do
        {:ok, code_block} ->
          lines = length(String.split(code_block, ~r/\n/))
          # Adjust based on your CSS padding/margins
          base_height = 100
          # Typical line height for code
          line_height = 24
          size = base_height + line_height * lines
          ceil(min(1100, size) / 100) * 100

        {:error, "No code block found"} ->
          0
      end

    resized_window_session = Browser.resize_window(session, 1000, code_block_size)
    new_session = Browser.visit(resized_window_session, url)

    %Wallaby.Session{screenshots: [screenshot]} = Browser.take_screenshot(new_session)
    Wallaby.end_session(session)
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
        {:ok, image_url}

      error ->
        error
    end
  end
end
