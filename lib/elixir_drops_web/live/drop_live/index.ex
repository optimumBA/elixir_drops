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
     |> assign(:drop_filters, %{screenshot_status: "published"})
     |> assign(:end_of_timeline?, false)
     |> assign(:new_drops?, false)
     |> assign(:page_title, "ElixirDrops")
     |> assign(:page, 1)
     |> DropsListHelper.assign_drops()}
  end

  @impl Phoenix.LiveView
  def handle_event("load-more", _params, socket) do
    DropsListHelper.load_more(socket)
  end

  def handle_event("refresh-drops", _params, socket) do
    {:noreply,
     socket
     |> assign(:new_drops?, false)
     |> DropsListHelper.assign_drops()}
  end

  @impl Phoenix.LiveView
  def handle_info({DropsBroadcast, [:drop, :created], drop}, socket) do
    has_screenshot = drop.screenshot && drop.screenshot.status != "pending"

    if has_screenshot do
      {:noreply, assign(socket, :new_drops?, true)}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info(
        {DropsBroadcast, [:drop, :screenshot_generation_progress],
         %{inserted_at: inserted_at} = _drop, _progress, "published"},
        socket
      ) do
    # TODO: Find a better way to do this
    is_new = NaiveDateTime.diff(NaiveDateTime.utc_now(), inserted_at, :second) <= 60

    if is_new do
      {:noreply,
       socket
       |> assign(:new_drops?, is_new)
       |> DropsListHelper.assign_drops()}
    else
      {:noreply, DropsListHelper.assign_drops(socket)}
    end
  end

  def handle_info(
        {DropsBroadcast, [:drop, :screenshot_generation_progress], _drop, _progress, _status},
        socket
      ) do
    {:noreply, socket}
  end
end
