defmodule ElixirDrops.Workers.ScreenshotGeneratorWorker do
  @moduledoc false

  use Oban.Worker, queue: :seo_images, max_attempts: 5
  use ElixirDropsWeb, :verified_routes

  alias ElixirDrops.Drops
  alias ElixirDrops.S3Helper.Client
  alias ElixirDrops.ScreenshotGenerator
  alias Wallaby.Browser

  require Logger

  @markdown_regex ~r/```([^`]*)```/

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    case check_code_block_and_update(args) do
      {:ok, image_url, session} ->
        Wallaby.end_session(session)
        Logger.info("Screenshot generated: #{image_url}")

      error ->
        Logger.error("#{inspect(error)}")
        error
    end

    :ok
  end

  defp check_code_block_and_update(args) do
    with {:ok, drop} <- get_drop(args["drop_id"]),
         :ok <- check_for_code_block(drop.body) do
      drop_screenshot(drop)
    end
  end

  defp drop_screenshot(drop) do
    FLAME.call(ScreenshotGenerator, fn ->
      with {:ok, screenshot, session} <- generate_screenshot(drop),
           {:ok, image} <- File.read(screenshot) do
        upload_screenshot(image, drop, session)
      end
    end)
  end

  defp get_drop(id) do
    case Drops.get_drop(%{drop_id: id}) do
      nil -> {:error, "Drop not found"}
      drop -> {:ok, drop}
    end
  end

  defp check_for_code_block(body) do
    case Regex.run(@markdown_regex, body, capture: :first) do
      nil -> {:error, "No code block found"}
      _code_block -> :ok
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
              "window-size=1280,800",
              "--fullscreen",
              "--disable-gpu",
              "--disable-dev-shm-usage"
            ]
          }
        }
      )

    url = build_url_with_auth(drop)

    %Wallaby.Session{screenshots: [screenshot]} =
      session
      |> Browser.visit(url)
      |> Browser.take_screenshot()

    {:ok, screenshot, session}
  end

  defp build_url_with_auth(drop) do
    auth_values = Application.get_env(:elixir_drops, :wallaby_auth)

    url = url(~p"/screenshot/#{drop.id}")

    [scheme, rest] = String.split(url, "//", parts: 2)

    "#{scheme}//#{auth_values[:username]}:#{auth_values[:password]}@#{rest}"
  end

  defp upload_screenshot(screenshot, drop, session) do
    timestamp = Timex.to_unix(drop.updated_at)

    image_name = "drop-meta-image-#{timestamp}-#{drop.id}.png"

    case Client.upload_image(screenshot, image_name, "image/png") do
      {:ok, image_url} ->
        {:ok, image_url, session}

      error ->
        error
    end
  end
end
