defmodule ElixirDropsWeb.DropLive.Show do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDropsWeb.DropLive.DropComponents

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :show_user_drops?, false)}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _url, socket) do
    {:noreply,
     id
     |> Drops.get_drop()
     |> assign_drop(socket)}
  end

  defp assign_drop(nil, socket) do
    socket
    |> assign(:drop, nil)
    |> push_patch(to: ~p"/")
  end

  defp assign_drop(drop, socket) do
    socket
    |> assign(:drop, drop)
    |> assign(:page_title, drop.title)
    |> assign_seo_attributes()
  end

  defp assign_seo_attributes(socket) do
    %{drop: drop} = socket.assigns

    image_url = Map.get(drop, :seo_image_link)

    attributes = %{
      description: drop.title,
      image_url: image_url,
      type: "article",
      url: url(~p"/drops/#{drop.id}")
    }

    assign(socket, :seo_attributes, attributes)
  end
end
