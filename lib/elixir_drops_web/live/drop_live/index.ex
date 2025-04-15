defmodule ElixirDropsWeb.DropLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.DropsBroadcast
  alias ElixirDrops.WorkerHelpers
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropsListHelper

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Drops.subscribe()

    {:ok,
     socket
     |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
     |> assign(:drop_filters, %{screenshot_status: :completed})
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
    needs_screenshot =
      case WorkerHelpers.check_for_code_block(drop.body) do
        {:ok, _code_block} -> true
        {:error, _reason} -> false
      end

    has_completed_screenshot = drop.screenshot && drop.screenshot.status == :completed

    if !needs_screenshot or has_completed_screenshot do
      {:noreply, assign(socket, :new_drops?, true)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        {DropsBroadcast, [:drop, :screenshot_generation_completion], _drop, _progress, :completed,
         %{action: "edit"} = _metadata},
        socket
      ) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(
        {DropsBroadcast, [:drop, :screenshot_generation_completion], _drop, _progress, :completed,
         %{action: "new"} = _metadata},
        socket
      ) do
    {:noreply, assign(socket, :new_drops?, true)}
  end
end
