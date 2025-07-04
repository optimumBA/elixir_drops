defmodule ElixirDropsWeb.DropsMountHook do
  @moduledoc """
  LiveView hook for common drops functionality.

  Provides common mount setup and event handling for drops-related LiveViews.
  """

  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDropsWeb.DropsLive
  alias ElixirDropsWeb.UserDropLive

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
      |> attach_hook(:search_event_handler, :handle_event, &handle_search_events/3)
      |> attach_hook(:search_params_handler, :handle_params, &handle_search_params/3)

    {:cont, socket}
  end

  defp handle_search_events("search", %{"query" => query}, socket) do
    params =
      if query != "" do
        %{q: query}
      else
        %{}
      end

    path =
      case socket.view do
        DropsLive.Index -> ~p"/?#{params}"
        UserDropLive.Index -> ~p"/profile?#{params}"
        _other_view -> ~p"/?#{params}"
      end

    {:halt, push_patch(socket, to: path)}
  end

  defp handle_search_events("clear_search", _params, socket),
    do: handle_search_events("search", %{"query" => ""}, socket)

  defp handle_search_events(_event, _params, socket), do: {:cont, socket}

  defp handle_search_params(params, _url, socket) do
    search_query =
      params
      |> Map.get("q", "")
      |> String.trim()

    {:cont, handle_search_from_params(socket, search_query)}
  end

  defp handle_search_from_params(%{assigns: %{search_query: search_query}} = socket, query)
       when search_query != query do
    filters =
      socket.assigns.drop_filters
      |> Map.put(:search, query)
      |> Map.delete(:older_than)

    socket
    |> assign(:drop_filters, filters)
    |> assign(:end_of_timeline?, false)
    |> assign(:new_drops?, false)
    |> assign(:page, 1)
    |> assign(:search_query, query)
    |> assign(:searching, query != "")
  end

  defp handle_search_from_params(socket, _query), do: socket
end
