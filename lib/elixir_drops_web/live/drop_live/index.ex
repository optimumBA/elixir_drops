defmodule ElixirDropsWeb.DropLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropsHelpers

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Drops.subscribe()

    {:ok,
     socket
     |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
     |> assign(:drop_filters, %{})
     |> assign(:end_of_timeline?, false)
     |> assign(:new_drops?, false)}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl Phoenix.LiveView
  def handle_event(event, params, socket)
      when event in [
             "next-page",
             "prev-page"
           ],
      do: DropsHelpers.handle_event(event, params, socket)

  # TODO: Fix ghost cards
  def handle_event("refresh-drops", _params, socket) do
    {:noreply,
     socket
     |> assign(:new_drops?, false)
     |> DropsHelpers.assign_drops()}
  end

  @impl Phoenix.LiveView
  def handle_info({Drops, [:drop, :created], _drop}, socket) do
    {:noreply, assign(socket, :new_drops?, true)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:drop, nil)
    |> assign(:page_title, "ElixirDrops")
    |> DropsHelpers.assign_drops()
  end
end
