defmodule ElixirDropsWeb.DropLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropsListHelper

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Drops.subscribe()

    {:ok,
     socket
     |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
     |> assign(:end_of_timeline?, false)
     |> assign(:new_drops?, false)}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, %{"tag" => tag}) do
    tag = DropsListHelper.process_tag(tag)

    socket
    |> assign(:drop_filters, %{tag: tag})
    |> assign(:page_title, "ElixirDrops | #{tag}")
    |> DropsListHelper.assign_drops()
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:drop_filters, %{})
    |> assign(:page_title, "ElixirDrops")
    |> DropsListHelper.assign_drops()
  end

  @impl Phoenix.LiveView
  def handle_event("next-page", _params, socket) do
    filters = %{older_than: socket.assigns.last_drop}

    {
      :noreply,
      DropsListHelper.maybe_insert_drops(socket, filters, socket.assigns.last_drop)
    }
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, socket}
  end

  def handle_event("prev-page", _params, socket) do
    filters = %{newer_than: socket.assigns.first_drop}

    {
      :noreply,
      DropsListHelper.maybe_insert_drops(socket, filters, socket.assigns.first_drop, at: 0)
    }
  end

  def handle_event("refresh-drops", _params, socket) do
    {:noreply,
     socket
     |> assign(:new_drops?, false)
     |> DropsListHelper.assign_drops()}
  end

  @impl Phoenix.LiveView
  def handle_info({Drops, [:drop, :created], drop}, socket) do
    {:noreply, DropsListHelper.maybe_show_new_drops_notification(socket, drop)}
  end
end
