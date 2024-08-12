defmodule ElixirDropsWeb.DropLive.Show do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDropsWeb.DropComponents

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :show_user_drops?, false)}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"unique_url_string" => unique_url_string}, _url, socket) do
    {:noreply,
     unique_url_string
     |> Drops.get_drop_by_unique_url_string()
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
  end
end
