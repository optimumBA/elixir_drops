defmodule ElixirDropsWeb.SeoMetaTagsComponent do
  @moduledoc false

  use ElixirDropsWeb, :verified_routes
  use Phoenix.Component

  alias ElixirDropsWeb.Endpoint

  @type assigns :: map()
  @type rendered :: rendered()

  @default_description """
  Share Elixir tips and tricks with the community...
  """

  @default_title "Elixir Drops"
  @default_type "website"

  attr :attributes, :map

  @spec seo_meta_tags(assigns()) :: rendered()
  def seo_meta_tags(assigns) do
    assigns =
      assigns
      |> assign_description()
      |> assign_image_url()
      |> assign_title()
      |> assign_type()
      |> assign_url()

    ~H"""
    <.open_graph_meta_tags
      description={@description}
      image_url={@image_url}
      title={@title}
      type={@type}
      url={@url}
    />

    <.other_meta_tags description={@description} />

    <.twitter_meta_tags
      description={@description}
      image_url={@image_url}
      title={@title}
      type={@type}
      url={@url}
    />
    """
  end

  defp assign_description(assigns) do
    assign_new(assigns, :description, fn
      %{attributes: %{description: description}} -> description
      _assigns -> String.trim(@default_description)
    end)
  end

  defp assign_image_url(assigns) do
    assign_new(assigns, :image_url, fn
      %{attributes: %{image_url: image_url}} when is_binary(image_url) -> image_url
      _assigns -> static_url(Endpoint, ~p"/images/seo_default_image.png")
    end)
  end

  defp assign_title(assigns) do
    assign_new(assigns, :title, fn
      %{attributes: %{title: title}} -> title
      _assigns -> @default_title
    end)
  end

  defp assign_type(assigns) do
    assign_new(assigns, :type, fn
      %{attributes: %{type: type}} -> type
      _assigns -> @default_type
    end)
  end

  defp assign_url(assigns) do
    assign_new(assigns, :url, fn
      %{attributes: %{url: url}} -> url
      _assigns -> url(~p"/")
    end)
  end

  attr :description, :string, required: true
  attr :image_url, :string, required: true
  attr :title, :string, required: true
  attr :type, :string, required: true
  attr :url, :string, required: true

  defp open_graph_meta_tags(assigns) do
    ~H"""
    <meta property="og:description" content={@description} />
    <meta property="og:image" content={@image_url} />
    <meta property="og:title" content={@title} />
    <meta property="og:type" content={@type} />
    <meta property="og:url" content={@url} />
    """
  end

  attr :description, :string, required: true

  defp other_meta_tags(assigns) do
    ~H"""
    <meta property="description" content={@description} />
    """
  end

  attr :description, :string, required: true
  attr :image_url, :string, required: true
  attr :title, :string, required: true
  attr :type, :string, required: true
  attr :url, :string, required: true

  defp twitter_meta_tags(assigns) do
    ~H"""
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:description" content={@description} />
    <meta name="twitter:image" content={@image_url} />
    <meta name="twitter:site" content="@optimumBA" />
    <meta name="twitter:title" content={@title} />
    <meta name="twitter:type" content={@type} />
    <meta name="twitter:url" content={@url} />
    """
  end
end
