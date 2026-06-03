defmodule ElixirDropsWeb.NavbarSearchHook do
  @moduledoc """
  on_mount hook for shared navbar search functionality across LiveViews.
  """

  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Search
  alias ElixirDropsWeb.SearchHelper

  @type socket :: Phoenix.LiveView.Socket.t()

  @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
  def on_mount(:navbar_search, _params, _session, socket) do
    user_id =
      if socket.assigns.current_user do
        socket.assigns.current_user.id
      end

    {:cont,
     socket
     |> SearchHelper.initialize_search_assigns(user_id)
     |> assign(:navbar_search_query, "")
     |> assign(:search_suggestions, [])
     |> assign(:show_suggestions?, false)
     |> attach_hook(:navbar_search_events, :handle_event, &handle_navbar_search_events/3)}
  end

  defp handle_navbar_search_events("focus_navbar_search", _params, socket) do
    {:noreply, updated_socket} =
      SearchHelper.handle_focus_search_input(socket, :search_suggestions)

    {:halt, updated_socket}
  end

  defp handle_navbar_search_events("blur_navbar_search", _params, socket) do
    {:halt, assign(socket, :show_suggestions?, false)}
  end

  defp handle_navbar_search_events("load_navbar_suggestions", %{"query" => query}, socket)
       when is_binary(query) do
    trimmed_query = String.trim(query)
    user = socket.assigns.current_user

    suggestions = get_navbar_suggestions(trimmed_query, user)
    show_suggestions? = String.length(trimmed_query) >= 2 && suggestions != []

    {:halt,
     socket
     |> assign(:navbar_search_query, query)
     |> assign(:search_suggestions, suggestions)
     |> assign(:show_suggestions?, show_suggestions?)}
  end

  defp handle_navbar_search_events("load_navbar_suggestions", _params, socket) do
    {:halt, socket}
  end

  defp handle_navbar_search_events("navbar_search_submit", _params, socket) do
    # Let the LiveView handle its own navbar_search_submit logic
    {:cont, socket}
  end

  defp handle_navbar_search_events("delete_navbar_search_history", %{"id" => history_id}, socket) do
    {:noreply, updated_socket} =
      SearchHelper.handle_delete_search_history(history_id, socket, :search_suggestions)

    {:halt, updated_socket}
  end

  defp handle_navbar_search_events("delete_navbar_search_history", _params, socket) do
    {:halt, socket}
  end

  defp handle_navbar_search_events(_event, _params, socket) do
    {:cont, socket}
  end

  # Helper functions
  defp get_navbar_suggestions(query, _user) when byte_size(query) < 2, do: []

  defp get_navbar_suggestions(query, %{id: user_id}) do
    Search.get_search_suggestions(user_id, query)
  end

  defp get_navbar_suggestions(query, nil) do
    Search.get_popular_search_suggestions(query, 5)
  end
end
