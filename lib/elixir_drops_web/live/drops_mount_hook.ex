defmodule ElixirDropsWeb.DropsMountHook do
  @moduledoc """
  LiveView hook for common drops functionality.

  Provides common mount setup and event handling for drops-related LiveViews.
  """

  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDropsWeb.DropsListHelper

  @type name :: atom()
  @type params :: map()
  @type session :: map()
  @type socket :: Phoenix.LiveView.Socket.t()

  @spec on_mount(name(), params(), session(), socket()) :: {:cont, socket()}
  def on_mount(:default, _params, _session, socket) do
    if connected?(socket), do: Drops.subscribe()

    socket =
      socket
      |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
      |> assign(:batch_size, 15)
      |> assign(:end_of_timeline?, false)
      |> assign(:initial_load, true)
      |> assign(:loading_more, false)
      |> assign(:page, 1)
      |> assign(:search_query, "")
      |> assign(:searching, false)
      |> assign(:viewport_height, nil)
      |> assign(:viewport_width, nil)
      |> attach_hook(:search_handler, :handle_event, &handle_search_events/3)

    {:cont, socket}
  end

  def on_mount(:homepage, _params, _session, socket) do
    socket =
      socket
      |> assign(:drop_filters, %{screenshot_status: [:completed, :skipped]})
      |> assign(:new_drops?, false)
      |> assign(:page_title, "ElixirDrops")
      |> DropsListHelper.assign_drops()

    {:cont, socket}
  end

  def on_mount(:user_drops, _params, _session, socket) do
    socket =
      socket
      |> assign(:drop_filters, %{user_id: socket.assigns.current_user.id})
      |> DropsListHelper.assign_drops()

    {:cont, socket}
  end

  defp handle_search_events("search", %{"query" => query}, socket) do
    socket =
      socket
      |> handle_search(query)
      |> reset_timeline_state()

    {:halt, socket}
  end

  defp handle_search_events("clear_search", _params, socket),
    do: handle_search_events("search", %{"query" => ""}, socket)

  defp handle_search_events(_event, _params, socket), do: {:cont, socket}

  defp handle_search(socket, query) do
    trimmed_query = String.trim(query)

    filters =
      socket.assigns.drop_filters
      |> Map.put(:search, trimmed_query)
      |> Map.delete(:older_than)

    socket
    |> assign(:drop_filters, filters)
    |> assign(:search_query, trimmed_query)
    |> assign(:searching, trimmed_query != "")
    |> Phoenix.LiveView.stream(:drops, [], reset: true)
    |> DropsListHelper.assign_drops()
  end

  defp reset_timeline_state(socket) do
    socket
    |> assign(:end_of_timeline?, false)
    |> assign(:new_drops?, false)
    |> assign(:page, 1)
  end
end
