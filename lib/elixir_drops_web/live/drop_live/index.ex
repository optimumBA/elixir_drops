defmodule ElixirDropsWeb.DropLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.DropsBroadcast
  alias ElixirDropsWeb.CodeBlockHelper
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropsListHelper

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Drops.subscribe()

    {:ok,
     socket
     |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
     |> assign(:drop_filters, %{screenshot_status: [:completed, :skipped]})
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
    if CodeBlockHelper.has_code_block?(drop.body) == false do
      {:noreply, assign(socket, :new_drops?, true)}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({DropsBroadcast, [:drop, :screenshot_generation_started], _drop}, socket) do
    {:noreply, socket}
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
