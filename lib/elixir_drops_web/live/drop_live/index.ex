defmodule ElixirDropsWeb.DropLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops.DropsBroadcast
  alias ElixirDropsWeb.CodeBlockHelper
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropsBatchCalculator
  alias ElixirDropsWeb.DropsListHelper

  on_mount {ElixirDropsWeb.DropsMountHook, :default}
  on_mount {ElixirDropsWeb.DropsMountHook, :homepage}

  @impl Phoenix.LiveView
  def handle_event("update-viewport", %{"width" => width, "height" => height}, socket) do
    batch_size = DropsBatchCalculator.calculate_batch_size(width, height)

    {:noreply,
     socket
     |> assign(:viewport_width, width)
     |> assign(:viewport_height, height)
     |> assign(:batch_size, batch_size)}
  end

  def handle_event("load-more", %{"layout_complete" => true}, socket) do
    socket = assign(socket, :loading_more, true)
    DropsListHelper.load_more(socket, socket.assigns.batch_size)
  end

  def handle_event("load-more", _params, socket) do
    socket = assign(socket, :loading_more, true)
    DropsListHelper.load_more(socket, socket.assigns.batch_size)
  end

  def handle_event("load-more-complete", _params, socket) do
    {:noreply, assign(socket, :loading_more, false)}
  end

  def handle_event("refresh-drops", _params, socket) do
    {:noreply,
     socket
     |> assign(:new_drops?, false)
     |> assign(:page, 1)
     |> DropsListHelper.assign_drops()}
  end

  @impl Phoenix.LiveView
  def handle_info({DropsBroadcast, _event, _drop}, %{assigns: %{searching: true}} = socket),
    do: {:noreply, socket}

  def handle_info({DropsBroadcast, [:drop, :created], drop}, socket) do
    if CodeBlockHelper.has_code_block?(drop.body) == false do
      {:noreply, assign(socket, :new_drops?, true)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({DropsBroadcast, [:drop, :screenshot_generation_started], _drop}, socket) do
    {:noreply, socket}
  end

  def handle_info(
        {DropsBroadcast, [:drop, :screenshot_generation_completion], _drop, _progress, :completed,
         %{action: "new"} = _metadata},
        socket
      ) do
    {:noreply, assign(socket, :new_drops?, true)}
  end

  def handle_info(
        {DropsBroadcast, [:drop, :screenshot_generation_completion], _drop, _progress, _status,
         _metadata},
        socket
      ) do
    {:noreply, socket}
  end
end
