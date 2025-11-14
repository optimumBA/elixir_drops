defmodule ElixirDropsWeb.UserDropLive.Bookmarks do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Bookmarks
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
        show_user_drops?={true}
      />
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(
        _params,
        %{
          "batch_size" => batch_size,
          "current_user" => current_user,
          "loading_more" => loading_more,
          "page" => page,
          "search_query" => search_query,
          "searching" => searching
        } = _session,
        socket
      ) do
    bookmarked_drops = Bookmarks.get_bookmarked_drops(current_user.id)

    {:ok,
     socket
     |> assign(:loading_more, loading_more)
     |> assign(:batch_size, batch_size)
     |> assign(:current_user, current_user)
     |> assign(:search_query, search_query)
     |> assign(:page, page)
     |> assign(:searching, searching)
     |> assign(:show_user_drops?, true)
     |> assign(:drops_empty?, false)
     |> assign(:end_of_timeline?, true)
     |> stream(:drops, bookmarked_drops)}
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
end
