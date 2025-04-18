defmodule ElixirDrops.Workers.ScreenshotGeneratorWorker do
  @moduledoc false

  use Oban.Worker, queue: :seo_images, max_attempts: 5
  use ElixirDropsWeb, :verified_routes

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.DropsBroadcast
  alias ElixirDrops.S3Helper.Client
  alias ElixirDrops.ScreenshotGenerator
  alias Wallaby.Browser

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    with {:ok, drop} <- get_drop(args["drop_id"]) do
      drop_screenshot(drop, args)
    end
  end

  defp drop_screenshot(drop, args) do
    FLAME.call(ScreenshotGenerator, fn ->
      with {:ok, screenshot} <- generate_screenshot(drop),
           {:ok, image} <- File.read(screenshot) do
        upload_screenshot(image, drop, args)
      end
    end)
  end

  defp get_drop(id) do
    case Drops.get_drop(%{drop_id: id}) do
      nil ->
        {:error, "Drop not found"}

      drop ->
        {:ok, drop}
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

    Wallaby.end_session(session)

    {:ok, screenshot}
  end

  defp build_url_with_auth(drop) do
    [username: username, password: password] = Application.get_env(:elixir_drops, :wallaby_auth)

    url = url(~p"/d/#{drop.id}/code_snippet")

    [scheme, rest] = String.split(url, "//", parts: 2)

    "#{scheme}//#{username}:#{password}@#{rest}"
  end

  defp upload_screenshot(screenshot, drop, args) do
    latest_image_name = "drop-meta-image-latest-#{drop.id}.png"

    case Client.upload_image(screenshot, latest_image_name, "image/png") do
      {:ok, image_url} ->
        case Drops.update_drop_screenshot(drop, %{
               screenshot: %{status: :completed, url: image_url}
             }) do
          {:ok, updated_drop} ->
            broadcast_drop_screenshot_completion(updated_drop, 100, :completed, %{
              action: args["action"]
            })

            :ok

          error ->
            error
        end

      error ->
        Drops.update_drop_screenshot(drop, %{screenshot: %{status: :failed}})
        error
    end
  end

  defp broadcast_drop_screenshot_completion(drop, progress, status, metadata) do
    DropsBroadcast.broadcast_drop_screenshot_completion(drop, progress, status, metadata)
  end
end
