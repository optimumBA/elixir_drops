defmodule ElixirDropsWeb.DropsHelpers do
  @moduledoc false

  import Phoenix.Component
  import Phoenix.LiveView

  alias ElixirDrops.Drops

  @type socket :: Phoenix.LiveView.Socket.t()

  @spec handle_event(event :: binary(), map(), socket()) :: {:noreply, socket()}
  def handle_event("next-page", _params, socket) do
    filters = %{older_than: socket.assigns.last_drop}

    {
      :noreply,
      maybe_insert_drops(socket, filters, socket.assigns.last_drop)
    }
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, socket}
  end

  def handle_event("prev-page", _params, socket) do
    filters = %{newer_than: socket.assigns.first_drop}

    {
      :noreply,
      maybe_insert_drops(socket, filters, socket.assigns.first_drop, at: 0)
    }
  end

  @spec assign_drops(socket()) :: socket()
  def assign_drops(socket) do
    drops = Drops.list_drops(socket.assigns.drop_filters)

    first_drop = List.first(drops)
    last_drop = List.last(drops)

    socket
    |> stream(:drops, drops, reset: true)
    |> assign(:first_drop, first_drop)
    |> assign(:last_drop, last_drop)
  end

  defp maybe_insert_drops(socket, _filters, _first_or_last_drop, _opts \\ [])

  defp maybe_insert_drops(socket, _filters, nil, _opts) do
    assign(socket, :end_of_timeline?, true)
  end

  defp maybe_insert_drops(socket, filters, _first_or_last_drop, opts) do
    drops =
      filters
      |> Map.merge(socket.assigns.drop_filters)
      |> Drops.list_drops()

    first_drop = List.first(drops)
    last_drop = List.last(drops)

    socket
    |> stream_insert_many(:drops, drops, opts)
    |> assign(:first_drop, first_drop)
    |> assign(:last_drop, last_drop)
  end

  defp stream_insert_many(socket, stream_key, items, opts) do
    Enum.reduce(items, socket, fn item, socket ->
      stream_insert(socket, stream_key, item, opts)
    end)
  end
end
