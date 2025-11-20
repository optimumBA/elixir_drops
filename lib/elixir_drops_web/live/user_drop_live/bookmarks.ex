defmodule ElixirDropsWeb.UserDropLive.Bookmarks do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Bookmarks
  alias ElixirDropsWeb.BookmarkHelpers
  alias ElixirDropsWeb.DropsListHelper

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
          "current_user" => current_user
        } = _session,
        socket
      ) do
    {:ok,
     socket
     |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
     |> assign(:batch_size, batch_size)
     |> assign(:bookmark_tab?, true)
     |> assign(:current_user, current_user)
     |> assign(:drop_filters, %{user_id: current_user.id})
     |> assign(:drops_empty?, true)
     |> assign(:loading_more, false)
     |> assign(:page, 1)
     |> assign(:search_query, "")
     |> assign(:searching, false)
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

  def handle_event(event, params, socket)
      when event in ["remove_from_bookmark", "bookmark_drop"],
      do: BookmarkHelpers.handle_bookmark_event(event, params, socket)

  defp assign_drops(socket) do
    batch_size = Map.get(socket.assigns, :batch_size, 15)

    bookmarks =
      Bookmarks.get_bookmarks(
        socket.assigns.drop_filters,
        batch_size
      )

    drops = Bookmarks.get_bookmarked_drops(bookmarks)
    last_bookmark = List.last(bookmarks)

    socket
    |> Phoenix.LiveView.stream(:drops, drops, reset: true, limit: batch_size)
    |> assign(:drops_empty?, Enum.empty?(drops))
    |> assign(:end_of_timeline?, false)
    |> assign(:last_bookmark, last_bookmark)
    |> assign(:loading_more, false)
  end

  defp load_more(socket, batch_size)

  defp load_more(%{assigns: %{end_of_timeline?: true}} = socket, _batch_size),
    do: {:noreply, socket}

  defp load_more(socket, _batch_size) do
    filters = %{older_than: socket.assigns.last_bookmark}

    socket =
      socket
      |> assign(:loading_more, false)
      |> assign(:page, socket.assigns.page + 1)
      |> maybe_insert_drops(filters, socket.assigns.last_bookmark)
      |> push_event("load-more-complete", %{})

    {:noreply, socket}
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
end
