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
     |> assign(:screenshot, %{
       status: :idle,
       drop_short_id: "",
       progress_value: 0,
       url: nil
     })
     |> assign(:end_of_timeline?, false)
     |> assign(:page, 1)
     |> DropsListHelper.assign_drops()}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl Phoenix.LiveView
  def handle_event("progress_animation_complete", _params, socket) do
    url = socket.assigns.screenshot.url
    status = if url, do: :completed, else: socket.assigns.screenshot.status

    {:noreply,
     assign(socket, :screenshot, %{
       status: status,
       drop_short_id: socket.assigns.screenshot.drop_short_id,
       progress_value: 100,
       url: url
     })}
  end

  @impl Phoenix.LiveView
  def handle_event("load-more", _params, socket) do
    DropsListHelper.load_more(socket)
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
    {:noreply,
     socket
     |> push_event("screenshot_generation_started", %{})
     |> assign(:screenshot, %{
       status: :pending,
       drop_short_id: socket.assigns.screenshot.drop_short_id,
       progress_value: 0,
       url: nil
     })}
  end

  def handle_info(
        {DropsBroadcast, [:drop, :screenshot_generation_progress], drop, progress, status,
         _metadata},
        socket
      ) do
    # Convert status to string for JavaScript
    status_string = Atom.to_string(status)
    url = if drop.screenshot, do: drop.screenshot.url, else: nil

    {:noreply,
     socket
     |> push_event("screenshot_progress_update", %{
       progress: progress,
       status: status_string,
       url: url
     })
     |> assign(:screenshot, %{
       status: status,
       drop_short_id: drop.short_id,
       progress_value: progress,
       url: url
     })
     |> DropsListHelper.assign_drops()}
  end
end
