defmodule ElixirDrops.Workers.ScreenshotGeneratorWorker do
  @moduledoc false

  use Oban.Worker, queue: :seo_images, max_attempts: 5
  use ElixirDropsWeb, :verified_routes

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.DropsBroadcast
  alias ElixirDrops.S3Helper.Client
  alias ElixirDrops.ScreenshotGenerator
  alias ElixirDrops.ScreenshotGeneratorWorkerHelper
  alias Wallaby.Browser

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    case Drops.get_drop(%{drop_id: args["drop_id"]}) do
      %Drops.Drop{} = drop ->
        drop_screenshots(drop, args)

      nil ->
        {:error, "Drop not found"}
    end
  end

  defp drop_screenshots(drop, args) do
    FLAME.call(ScreenshotGenerator, fn ->
      broadcast_drop_screenshot_completion(drop, 50, :pending, %{action: args["action"]})

      with {:ok, screenshots} <- generate_screenshots(drop, args["action"]),
           {:ok, meta_image} <- File.read(screenshots.meta),
           {:ok, internal_image} <- File.read(screenshots.internal),
           :ok <-
             upload_screenshots(
               %{meta: meta_image, internal: internal_image},
               drop,
               args["action"]
             ) do
        :ok
      else
        {:error, error} ->
          Drops.update_drop(drop, drop.user, %{
            screenshot: %{status: :failed, meta_url: nil, internal_url: nil}
          })

          {:error, error}
      end
    end)
  end

  defp generate_screenshots(drop, action) do
    height = ScreenshotGeneratorWorkerHelper.calc_height(drop.body)

    with {:ok, meta_screenshot} <- generate_screenshot(drop, :meta, action, height),
         {:ok, internal_screenshot} <- generate_screenshot(drop, :internal, action, height) do
      {:ok, %{meta: meta_screenshot, internal: internal_screenshot}}
    end
  end

  defp generate_screenshot(drop, type, action, height) do
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

    broadcast_drop_screenshot_completion(drop, if(type == :meta, do: 60, else: 70), :pending, %{
      action: action
    })

    url = build_url_with_auth(drop, type)

    %Wallaby.Session{screenshots: [screenshot]} =
      session
      |> Browser.visit(url)
      |> Browser.take_screenshot()

    Wallaby.end_session(session)

    broadcast_drop_screenshot_completion(drop, if(type == :meta, do: 65, else: 75), :pending, %{
      action: action
    })

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

  defp upload_screenshots(screenshots, drop, action) do
    latest_meta_image_name = "drop-meta-image-latest-#{drop.id}.png"
    latest_internal_image_name = "drop-internal-image-latest-#{drop.id}.png"

    broadcast_drop_screenshot_completion(drop, 80, :pending, %{action: action})

    {meta_result, meta_url} =
      Client.upload_image(screenshots.meta, latest_meta_image_name, "image/png")

    broadcast_drop_screenshot_completion(drop, 85, :pending, %{action: action})

    {internal_result, internal_url} =
      Client.upload_image(screenshots.internal, latest_internal_image_name, "image/png")

    broadcast_drop_screenshot_completion(drop, 90, :pending, %{action: action})

    case {meta_result, internal_result} do
      {:ok, :ok} ->
        {:ok, updated_drop} =
          Drops.update_drop(drop, drop.user, %{
            screenshot: %{
              status: :completed,
              meta_url: meta_url,
              internal_url: internal_url
            }
          })

        # Hack to ensure the image is ready to be served from Tigris
        :timer.sleep(1500)

        broadcast_drop_screenshot_completion(updated_drop, 100, :completed, %{action: action})

        :ok

      {:error, :ok} ->
        {:error, "Failed to upload meta screenshot"}

      {:ok, :error} ->
        {:error, "Failed to upload internal screenshot"}

      {:error, :error} ->
        {:error, "Failed to upload both screenshots"}
    end
  end

  defp broadcast_drop_screenshot_completion(drop, progress, status, metadata) do
    DropsBroadcast.broadcast_drop_screenshot_completion(drop, progress, status, metadata)
  end
end
