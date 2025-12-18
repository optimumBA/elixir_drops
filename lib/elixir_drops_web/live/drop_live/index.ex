defmodule ElixirDropsWeb.DropLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.DropsBroadcast
  alias ElixirDrops.Search
  alias ElixirDropsWeb.CodeBlockHelper
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropsBatchCalculator
  alias ElixirDropsWeb.DropsListHelper
  alias ElixirDropsWeb.SearchHelper

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Drops.subscribe()

    {:ok,
     socket
     |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
     |> assign(:batch_size, 15)
     |> assign(:drop_filters, %{screenshot_status: [:completed, :skipped]})
     |> assign(:drops_empty?, true)
     |> assign(:end_of_timeline?, false)
     |> assign(:loading_more, false)
     |> assign(:new_drops?, false)
     |> assign(:page_title, "ElixirDrops")
     |> assign(:page, 1)
     |> assign(:search_query, "")
     |> assign(:searching, false)
     |> assign(:viewport_height, nil)
     |> assign(:viewport_width, nil)}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    search_query = params["q"] || ""

    socket =
      socket
      |> assign(:navbar_search_query, search_query)
      |> assign(:search_query, search_query)
      |> assign(:searching, search_query != "")
      |> update_search_filters(search_query)
      |> DropsListHelper.assign_drops()

    {:noreply, socket}
  end

  defp update_search_filters(socket, search_query) do
    current_filters = socket.assigns.drop_filters

    filters =
      if search_query != "" do
        current_filters
        |> Map.put(:relevance_rank, {1, search_query})
        |> Map.put(:search, search_query)
      else
        Map.delete(current_filters, :search)
      end

    assign(socket, :drop_filters, filters)
  end

  @impl Phoenix.LiveView
  def handle_event("update-viewport", %{"width" => width, "height" => height}, socket) do
    batch_size = DropsBatchCalculator.calculate_batch_size(width, height)

    {:noreply,
     socket
     |> assign(:batch_size, batch_size)
     |> assign(:viewport_height, height)
     |> assign(:viewport_width, width)}
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

  def handle_event("search_submit", %{"query" => query}, socket) do
    trimmed_query =
      query
      |> to_string()
      |> String.trim()

    # Track search history and popular searches
    current_filters = update_search_filters(socket, trimmed_query).assigns.drop_filters
    SearchHelper.track_search(query, socket, current_filters)

    socket =
      socket
      |> assign(:search_query, trimmed_query)
      |> assign(:search_suggestions, [])
      |> assign(:searching, trimmed_query != "")
      |> assign(:show_suggestions, false)

    # Update URL and trigger search
    {:noreply,
     push_patch(socket, to: ~p"/?#{if trimmed_query != "", do: [q: trimmed_query], else: []}")}
  end

  def handle_event("load_suggestions", %{"query" => query}, socket) when is_binary(query) do
    trimmed_query = String.trim(query)

    cond do
      String.length(trimmed_query) < 2 ->
        {:noreply,
         socket
         |> assign(:search_suggestions, [])
         |> assign(:show_suggestions, false)}

      socket.assigns.current_user ->
        suggestions = Search.get_search_suggestions(socket.assigns.current_user.id, query)

        {:noreply,
         socket
         |> assign(:search_suggestions, suggestions)
         |> assign(:show_suggestions, true)}

      true ->
        # For unauthenticated users, show only popular searches
        suggestions = Search.get_popular_search_suggestions(trimmed_query, 5)

        {:noreply,
         socket
         |> assign(:search_suggestions, suggestions)
         |> assign(:show_suggestions, true)}
    end
  end

  def handle_event("load_suggestions", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_suggestions, [])
     |> assign(:show_suggestions, false)}
  end

  def handle_event("delete_search_history", %{"id" => history_id}, socket) do
    with %{current_user: %{id: user_id}} <- socket.assigns,
         {:ok, _} <- Search.delete_search_history(history_id, user_id) do
      # Re-fetch suggestions like focus does
      {suggestions, _} = SearchHelper.get_focus_search_suggestions(user_id)
      {:noreply, assign(socket, :search_suggestions, suggestions)}
    else
      _error -> {:noreply, socket}
    end
  end

  def handle_event("close_search_overlay", _params, socket) do
    {:noreply, assign(socket, :show_suggestions, false)}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:navbar_search_query, "")
     |> assign(:search_query, "")
     |> assign(:search_suggestions, [])
     |> assign(:show_suggestions, false)
     |> push_patch(to: ~p"/")}
  end

  def handle_event("focus_search_input", _params, socket) do
    SearchHelper.handle_focus_search_input(socket, :search_suggestions)
  end

  def handle_event("blur_search_input", _params, socket) do
    {:noreply, assign(socket, :show_suggestions, false)}
  end

  def handle_event("navbar_search_submit", %{"query" => query}, socket) do
    trimmed_query = String.trim(query)
    # Track search history and popular searches
    current_filters = update_search_filters(socket, trimmed_query).assigns.drop_filters
    SearchHelper.track_search(query, socket, current_filters)

    socket =
      socket
      |> assign(:navbar_search_query, trimmed_query)
      |> assign(:search_suggestions, [])
      |> assign(:show_suggestions, false)

    # Use push_navigate to force a masonry refresh
    if trimmed_query != "" do
      {:noreply, push_navigate(socket, to: ~p"/?q=#{trimmed_query}")}
    else
      {:noreply, push_patch(socket, to: ~p"/")}
    end
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

  @impl Phoenix.LiveView
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
