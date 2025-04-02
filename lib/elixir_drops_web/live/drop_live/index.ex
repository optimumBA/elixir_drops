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

  @impl true
  def handle_event("load-more", _, %{assigns: assigns} = socket) do
    case assigns.end_of_timeline? == true do
      true ->
        {:noreply, socket}

      false ->
        filters = %{older_than: socket.assigns.last_drop}

        {:noreply,
         assign(socket, page: assigns.page + 1)
         |> DropsListHelper.maybe_insert_drops(filters, socket.assigns.last_drop)}
    end
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
end
