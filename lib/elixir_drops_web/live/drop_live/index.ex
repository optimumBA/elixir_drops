defmodule ElixirDropsWeb.DropLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropsListComponent

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Drops.subscribe()

    {:ok,
     socket
     |> assign(:drop_filters, %{})
     |> assign(:new_drops?, false)
     |> assign(:page_title, "ElixirDrops")}
  end

  @impl Phoenix.LiveView
  def handle_info({Drops, [:drop, :created], _drop}, socket) do
    {:noreply, assign(socket, :new_drops?, true)}
  end

  def handle_info({:refreshed_drops?, true}, socket) do
    {:noreply, assign(socket, :new_drops?, false)}
  end
end
