defmodule ElixirDrops.Workers.ImageCreationWorker do
  @moduledoc false

  use Oban.Worker, queue: :seo_images, max_attempts: 1
  use ElixirDropsWeb, :verified_routes

  alias ElixirDrops.Drops
  alias ElixirDrops.S3Helper.Client
  alias Wallaby.Browser

  require Logger

  @markdown_regex ~r/```([^`]*)```/

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    case check_code_block_and_update(args) do
      {:ok, screenshot} ->
        File.rm!(screenshot)

      error ->
        Logger.error("#{inspect(error)}")
        error
    end

    :ok
  end

  defp check_code_block_and_update(args) do
    with {:ok, drop} <- get_drop(args["drop_id"]),
         {:ok, code_block} <- get_first_code_block(drop.body),
         {:ok, screenshot} <- generate_screenshot(code_block),
         {:ok, image} <- File.read(screenshot),
         {:ok, image_url} <- upload_screenshot(image, drop),
         {:ok, _drop} <- update_drop(drop, image_url) do
      {:ok, screenshot}
    end
  end

  defp get_drop(id) do
    case Drops.get_drop(id) do
      nil -> {:error, "Drop not found"}
      drop -> {:ok, drop}
    end
  end

  defp get_first_code_block(body) do
    case Regex.run(@markdown_regex, body, capture: :first) do
      nil -> {:error, "No code block found"}
      [code_block] -> {:ok, code_block}
    end
  end

  defp generate_screenshot(markdown) do
    {:ok, session} = Wallaby.start_session()

    url = build_url_with_auth(markdown)

    %Wallaby.Session{screenshots: [screenshot]} =
      session
      |> Browser.visit(url)
      |> Browser.take_screenshot()

    Wallaby.end_session(session)

    {:ok, screenshot}
  end

  defp build_url_with_auth(markdown) do
    auth_values = Application.get_env(:elixir_drops, :wallaby_auth)

    url = url(~p"/seo/#{markdown}")

    [scheme, rest] = String.split(url, "//", parts: 2)

    "#{scheme}//#{auth_values[:username]}:#{auth_values[:password]}@#{rest}"
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

  defp update_drop(drop, image_url) do
    case Drops.update_drop(drop, drop.user, %{seo_image_link: image_url}) do
      {:ok, drop} ->
        {:ok, drop}

      error ->
        error
    end
  end
end
