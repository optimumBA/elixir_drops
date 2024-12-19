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
     |> assign(:end_of_timeline?, false)
     |> assign(:new_drops?, false)
     |> assign(:page, 1)
     |> assign(:page_title, "ElixirDrops")
     |> DropsListHelper.assign_drops()}
  end

  @impl Phoenix.LiveView
  def handle_event("next-page", _params, socket) do
    filters = %{older_than: socket.assigns.last_drop}

    {
      :noreply,
      socket
      # Increment page number
      |> assign(:page, socket.assigns.page + 1)
      |> DropsListHelper.maybe_insert_drops(filters, socket.assigns.last_drop)
    }
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {
      :noreply,
      socket
      |> assign(:page, 1)
      |> DropsListHelper.assign_drops()
    }
  end

  def handle_event("prev-page", _params, socket) do
    if socket.assigns.page > 1 do
      filters = %{newer_than: socket.assigns.first_drop}

      {
        :noreply,
        socket
        |> assign(:page, socket.assigns.page - 1)
        |> DropsListHelper.maybe_insert_drops(filters, socket.assigns.first_drop)
      }
    else
      {:noreply, socket}
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
