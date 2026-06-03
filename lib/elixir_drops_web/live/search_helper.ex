defmodule ElixirDropsWeb.SearchHelper do
  @moduledoc """
  Shared search functionality for LiveViews.
  """

  import Phoenix.Component, only: [assign: 3]

  alias ElixirDrops.Drops
  alias ElixirDrops.Search

  @doc """
  Tracks search history and popular searches for a given query.
  """
  @spec track_search(String.t(), Phoenix.LiveView.Socket.t(), map()) :: :ok
  def track_search(query, socket, filters) do
    trimmed_query =
      query
      |> to_string()
      |> String.trim()

    # Track search history and popular searches
    if trimmed_query != "" do
      track_search_for_user(trimmed_query, socket.assigns.current_user, filters)
    end

    :ok
  end

  defp track_search_for_user(query, nil, _filters) do
    # For unauthenticated users, only track popular searches
    Task.start(fn ->
      Search.track_popular_search(query)
    end)
  end

  defp track_search_for_user(query, user, filters) do
    # Get current drops count for results tracking
    drops_count = length(Drops.list_drops(filters, 100))

    Task.start(fn ->
      Search.create_search_history(%{
        user_id: user.id,
        query: query,
        results_count: drops_count
      })

      Search.track_popular_search(query)
    end)
  end

  @doc """
  Gets recent search history suggestions for focus event.
  Returns tuple of {suggestions, show_suggestions_flag}.
  """
  @spec get_focus_search_suggestions(binary() | nil) :: {list(map()), boolean()}
  def get_focus_search_suggestions(user_id) do
    # Use get_search_suggestions with empty query to get initial suggestions
    suggestions = Search.get_search_suggestions(user_id, "")
    {suggestions, suggestions != []}
  end

  @doc """
  Handles focus search input event for both authenticated and unauthenticated users.
  """
  @spec handle_focus_search_input(Phoenix.LiveView.Socket.t(), atom()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_focus_search_input(socket, suggestions_assign_key) do
    if socket.assigns.current_user do
      user_id = socket.assigns.current_user.id
      {suggestions, show_suggestions?} = get_focus_search_suggestions(user_id)

      {:noreply,
       socket
       |> assign(suggestions_assign_key, suggestions)
       |> assign(:show_suggestions?, show_suggestions?)}
    else
      # For unauthenticated users, show top popular searches
      suggestions =
        Search.list_popular_searches()
        |> Enum.take(5)
        |> Enum.map(&%{query: &1.query, type: :popular})

      {:noreply,
       socket
       |> assign(suggestions_assign_key, suggestions)
       |> assign(:show_suggestions?, suggestions != [])}
    end
  end

  @doc """
  Handles delete search history event.
  """
  @spec handle_delete_search_history(String.t(), Phoenix.LiveView.Socket.t(), atom()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_delete_search_history(id, socket, suggestions_assign_key) do
    if socket.assigns.current_user do
      case Search.delete_search_history(id, socket.assigns.current_user.id) do
        {:ok, _search_history} ->
          # Re-fetch suggestions to update the list
          user_id = socket.assigns.current_user.id
          {suggestions, _show?} = get_focus_search_suggestions(user_id)
          {:noreply, assign(socket, suggestions_assign_key, suggestions)}

        {:error, _reason} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @doc """
  Initializes search-related assigns for LiveView mount.
  """
  @spec initialize_search_assigns(Phoenix.LiveView.Socket.t(), binary() | nil) ::
          Phoenix.LiveView.Socket.t()
  def initialize_search_assigns(socket, current_user_id) do
    {initial_suggestions, _} = get_focus_search_suggestions(current_user_id)

    socket
    |> assign(:navbar_search_query, "")
    |> assign(:searching, false)
    |> assign(:show_suggestions?, false)
    |> assign(:search_suggestions, initial_suggestions)
  end

  @doc """
  Initializes search-related assigns for user profile LiveView mount (includes profile search).
  """
  @spec initialize_profile_search_assigns(Phoenix.LiveView.Socket.t(), binary() | nil) ::
          Phoenix.LiveView.Socket.t()
  def initialize_profile_search_assigns(socket, current_user_id) do
    {initial_suggestions, _} = get_focus_search_suggestions(current_user_id)

    socket
    |> assign(:navbar_search_query, "")
    |> assign(:profile_search_suggestions, initial_suggestions)
    |> assign(:searching, false)
    |> assign(:search_suggestions, initial_suggestions)
    |> assign(:show_profile_suggestions?, false)
    |> assign(:show_suggestions?, false)
  end
end
