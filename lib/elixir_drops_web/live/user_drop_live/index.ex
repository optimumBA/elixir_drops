defmodule ElixirDropsWeb.UserDropLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.DropsBroadcast
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropsListHelper
  alias ElixirDropsWeb.UserDropLive.FormComponent

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Drops.subscribe()

    {:ok,
     socket
     |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
     |> assign(:drop_filters, %{user_id: socket.assigns.current_user.id})
     |> assign(:screenshot_status, :idle)
     |> assign(:screenshot_drop_short_id, "")
     |> assign(:progress_value, 0)
     |> assign(:screenshot_url, nil)
     |> assign(:end_of_timeline?, false)
     |> DropsListHelper.assign_drops()}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
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

  defp apply_action(socket, :edit, %{"short_id" => short_id}) do
    filters = %{
      short_id: short_id,
      user_id: socket.assigns.current_user.id
    }

    assign_user_drop(socket, filters)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:drop, %Drop{})
    |> assign(:page_title, "Create Drop")
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:drop, nil)
    |> assign(:page_title, "ElixirDrops | #{socket.assigns.current_user.github_username}")
  end

  defp assign_user_drop(socket, filters) do
    case Drops.get_drop(filters) do
      nil ->
        socket
        |> assign(:drop, nil)
        |> push_navigate(to: ~p"/")

      %Drop{} = drop ->
        socket
        |> assign(:drop, drop)
        |> assign(:page_title, "Edit Drop")
    end
  end

  @impl Phoenix.LiveView
  def handle_info({DropsBroadcast, [:drop, :created], _drop}, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(:screenshot_generation_started, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(
        {DropsBroadcast, [:drop, :screenshot_generation_progress], drop, progress, status},
        socket
      ) do
    if drop.screenshot_url do
      socket =
        socket
        |> assign(:screenshot_drop_short_id, drop.short_id)
        |> assign(:progress_value, 100)
        |> assign(:screenshot_status, :completed)
        |> assign(:screenshot_url, drop.screenshot_url)

      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:progress_value, progress)
        |> assign(:screenshot_status, status)

      {:noreply, socket}
    end
  end
end
