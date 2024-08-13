defmodule ElixirDropsWeb.DropsSeoTagsExtractor do
  @moduledoc false

  use ElixirDropsWeb, :verified_routes

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.S3Helper.Client
  alias Wallaby.Browser

  @type drop() :: Drop.t()
  @type image_url :: binary()

  @image_regex ~r/(?<alt>!\[[^\]]*\])\((?<filename>.*?)(?=\"|\))\)/
  @markdown_regex ~r/```[a-z]*\n[\s\S]*?\n```/

  @spec create_drop_meta_image(drop()) :: image_url() | nil
  def create_drop_meta_image(drop) do
    %Drop{body: body} = drop

    body
    |> get_first_code_block()
    |> maybe_get_first_image_or_return_code_block(drop)
    |> get_image_url(drop)
  end

  defp get_first_code_block(body), do: Regex.run(@markdown_regex, body, capture: :first)

  defp maybe_get_first_image_or_return_code_block(nil, drop),
    do: Regex.run(@image_regex, drop.body, capture: :first)

  defp maybe_get_first_image_or_return_code_block(code_block, _drop), do: code_block

  defp get_image_url(nil, _drop), do: nil

  defp get_image_url(markdown_block, drop) do
    screenshot = generate_screenshot(markdown_block)

    image_url =
      screenshot
      |> File.read!()
      |> upload_image(drop)

    File.rm!(screenshot)

    image_url
  end

  defp generate_screenshot(markdown_block) do
    {:ok, session} = Wallaby.start_session()

    %Wallaby.Session{screenshots: [screenshot]} =
      session
      |> Browser.visit(url(~p"/seo/#{markdown_block}"))
      |> Browser.take_screenshot()

    Wallaby.end_session(session)

    screenshot
  end

  defp upload_image(image, drop) do
    timestamp = Timex.to_unix(drop.updated_at)

    image_name = "drop-meta-image-#{timestamp}-#{drop.id}.png"

    case Client.upload_image(image, image_name, "image/png") do
      {:ok, image_url} ->
        image_url

      _error ->
        nil
    end
  end
end
