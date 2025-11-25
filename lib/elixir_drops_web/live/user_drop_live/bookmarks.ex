defmodule ElixirDropsWeb.UserDropLive.Bookmarks do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Accounts
  alias ElixirDrops.Bookmarks
  alias ElixirDropsWeb.BookmarkHelpers
  alias ElixirDropsWeb.DropsListHelper
  alias ElixirDropsWeb.SearchHelper

  @type rendered :: Phoenix.LiveView.Rendered.t()
  @type socket :: Phoenix.LiveView.Socket.t()

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div>
      <DropsListHelper.drops_list
        batch_size={@batch_size}
        current_user={@current_user}
        drops={@streams.drops}
        drops_empty?={@drops_empty?}
        end_of_timeline?={@end_of_timeline?}
        id="bookmarked-drops"
        loading_more={@loading_more}
        page={@page}
        search_query={@search_query}
        searching={@searching}
      />
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(
        _params,
        %{
          "batch_size" => batch_size,
          "user_id" => user_id,
          "bookmark_search_query" => bookmark_search_query
        } = _session,
        socket
      ) do
    send(socket.parent_pid, {:update_input_field, bookmark_search_query})

    user = Accounts.get_user!(user_id)

    {:ok,
     socket
     |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
     |> assign(:batch_size, batch_size)
     |> assign(:bookmark_tab?, true)
     |> assign(:current_user, user)
     |> assign(:drop_filters, %{user_id: user.id})
     |> assign(:drops_empty?, true)
     |> assign(:loading_more, false)
     |> assign(:page, 1)
     |> assign(:search_query, bookmark_search_query)
     |> assign(:searching, false)
     |> update_search_filters(bookmark_search_query)
     |> assign_drops()}
  end

  @impl Phoenix.LiveView
  def handle_event("update-viewport", %{"width" => width, "height" => height}, socket) do
    batch_size = ElixirDropsWeb.DropsBatchCalculator.calculate_batch_size(width, height)

    {:noreply,
     socket
     |> assign(:viewport_width, width)
     |> assign(:viewport_height, height)
     |> assign(:batch_size, batch_size)}
  end

  def handle_event("load-more", %{"layout_complete" => true}, socket) do
    socket = assign(socket, :loading_more, true)
    load_more(socket, socket.assigns.batch_size)
  end

  def handle_event("load-more", _params, socket) do
    socket = assign(socket, :loading_more, true)
    load_more(socket, socket.assigns.batch_size)
  end

  def handle_event("load-more-complete", _params, socket) do
    {:noreply, assign(socket, :loading_more, false)}
  end

  def handle_event("search_submit", %{"query" => query}, socket) do
    trimmed_query =
      query
      |> to_string()
      |> String.trim()

    # Track search history and popular searches
    SearchHelper.track_search(query, socket, %{})

    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:show_profile_suggestions, false)
      |> assign(:profile_search_suggestions, [])

    # Stay on profile page with search query
    if trimmed_query != "" do
      {:noreply,
       push_navigate(socket,
         to: ~p"/profile?bookmarks_user_id=#{socket.assigns.current_user.id}&bq=#{trimmed_query}"
       )}
    else
      {:noreply, push_navigate(socket, to: ~p"/profile")}
    end
  end

  def handle_event(event, params, socket)
      when event in ["remove_from_bookmark", "bookmark_drop"],
      do: BookmarkHelpers.handle_bookmark_event(event, params, socket)

  defp maybe_insert_drops(socket) do
    search_query = socket.assigns.search_query
    drop_filters = socket.assigns.drop_filters
    batch_size = Map.get(socket.assigns, :batch_size, 15)

    bookmarks =
      Bookmarks.get_bookmarks(
        socket.assigns.drop_filters,
        batch_size
      )

    drops = Bookmarks.get_bookmarked_drops(bookmarks)

    relevance_rank =
      if Enum.empty?(drops) do
        {0, search_query}
      else
        last_bookmark = List.last(bookmarks)

        {last_bookmark.relevance_rank, search_query}
      end

    filters =
      Map.put(drop_filters, :relevance_rank, relevance_rank)

    socket
    |> Phoenix.LiveView.stream(:drops, drops)
    |> assign(:drop_filters, filters)
    |> assign(:end_of_timeline?, Enum.count(drops) < batch_size)
  end

  defp assign_drops(socket) do
    batch_size = Map.get(socket.assigns, :batch_size, 15)

    bookmarks =
      Bookmarks.get_bookmarks(
        socket.assigns.drop_filters,
        batch_size
      )

    drops = Bookmarks.get_bookmarked_drops(bookmarks)

    socket
    |> assign_drop_cursor(bookmarks, socket.assigns.search_query)
    |> Phoenix.LiveView.stream(:drops, drops, reset: true, limit: batch_size)
    |> assign(:drops_empty?, Enum.empty?(drops))
    |> assign(:end_of_timeline?, false)
    |> assign(:loading_more, false)
  end

  defp assign_drop_cursor(socket, bookmarks, search_query)
       when search_query != "" and bookmarks != [] do
    last_bookmark = List.last(bookmarks)

    filters =
      Map.put(
        socket.assigns.drop_filters,
        :relevance_rank,
        {last_bookmark.relevance_rank, search_query}
      )

    assign(socket, :drop_filters, filters)
  end

  defp assign_drop_cursor(socket, bookmarks, _search_query) do
    last_bookmark = List.last(bookmarks)
    assign(socket, :last_bookmark, last_bookmark)
  end

  defp load_more(socket, batch_size)

  defp load_more(%{assigns: %{end_of_timeline?: true}} = socket, _batch_size),
    do: {:noreply, socket}

  defp load_more(socket, _batch_size) do
    socket = assign_drops_with_cursor(socket.assigns.search_query, socket)

    {:noreply, socket}
  end

  defp assign_drops_with_cursor(search_query, socket) when search_query != "" do
    socket
    |> assign(:loading_more, false)
    |> assign(:page, socket.assigns.page + 1)
    |> maybe_insert_drops()
    |> Phoenix.LiveView.push_event("load-more-complete", %{})
  end

  defp assign_drops_with_cursor(_search_query, socket) do
    filters = %{older_than: socket.assigns.last_bookmark}

    socket
    |> assign(:loading_more, false)
    |> assign(:page, socket.assigns.page + 1)
    |> maybe_insert_drops(filters, socket.assigns.last_bookmark)
    |> push_event("load-more-complete", %{})
  end

  defp maybe_insert_drops(socket, _filters, _first_or_last_bookmark, _opts \\ [])

  defp maybe_insert_drops(socket, _filters, nil, _opts) do
    assign(socket, :end_of_timeline?, true)
  end

  defp maybe_insert_drops(socket, filters, _first_or_last_bookmark, opts) do
    batch_size = Map.get(socket.assigns, :batch_size, 15)

    bookmarks =
      filters
      |> Map.merge(socket.assigns.drop_filters)
      |> Bookmarks.get_bookmarks(batch_size)

    drops = Bookmarks.get_bookmarked_drops(bookmarks)

    last_bookmark = List.last(bookmarks)

    socket
    |> Phoenix.LiveView.stream(:drops, drops, opts)
    |> assign(:end_of_timeline?, Enum.count(drops) < batch_size)
    |> assign(:last_bookmark, last_bookmark)
  end

  defp update_search_filters(socket, search_query) do
    current_filters = socket.assigns.drop_filters

    filters =
      if search_query != "" do
        Map.put(current_filters, :search, search_query)
      else
        Map.delete(current_filters, :search)
      end

    assign(socket, :drop_filters, filters)
  end
end
