defmodule ElixirDropsWeb.DropLive.Show do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDrops.S3Helper.Client
  alias ElixirDropsWeb.DropComponents

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _url, socket) do
    drop = Drops.get_drop(%{drop_id: id})

    {:noreply,
     socket
     |> assign(:show_user_drops?, false)
     |> assign_drop(drop)}
  end

  defp assign_drop(socket, nil) do
    socket
    |> assign(:drop, nil)
    |> push_patch(to: ~p"/")
  end

  defp assign_drop(socket, drop) do
    socket
    |> assign(:drop, drop)
    |> assign(:page_title, drop.title)
    |> assign_seo_attributes()
  end

  defp assign_seo_attributes(socket) do
    %{drop: drop} = socket.assigns

    attributes = %{
      description: drop.title,
      image_url: get_image_url(drop),
      type: "article",
      url: url(~p"/drops/#{drop.id}")
    }

    assign(socket, :seo_attributes, attributes)
  end

  defp get_image_url(drop) do
    case Client.get_image(drop) do
      {:ok, url} -> url
      _error -> nil
    end
  end
end
