defmodule ElixirDropsWeb.DropLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.DropsBroadcast
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropsListHelper

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Drops.subscribe()

    {:ok,
     socket
     |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
     |> assign(:drop_filters, %{})
     |> assign(:new_drops?, false)
     |> assign(:end_of_timeline?, false)
     |> assign(:page_title, "ElixirDrops")
     |> assign(page: 1)
     |> DropsListHelper.assign_drops()}
  end

  @impl Phoenix.LiveView
  def handle_event("load-more", _params, socket) do
    load_more(socket)
  end

  def handle_event("refresh-drops", _params, socket) do
    {:noreply,
     socket
     |> assign(:new_drops?, false)
     |> DropsListHelper.assign_drops()}
  end

  @impl Phoenix.LiveView
  def handle_info({DropsBroadcast, [:drop, :created], _drop}, socket) do
    {:noreply, assign(socket, :new_drops?, true)}
  end

  @spec load_more(any()) :: {:noreply, any()}
  def load_more(socket) do
    case socket.assigns.end_of_timeline? == true do
      true ->
        {:noreply, socket}

      false ->
        filters = %{older_than: socket.assigns.last_drop}

        socket = assign(socket, page: socket.assigns.page + 1)

        {:noreply, DropsListHelper.maybe_insert_drops(socket, filters, socket.assigns.last_drop)}
    end
  end
end
