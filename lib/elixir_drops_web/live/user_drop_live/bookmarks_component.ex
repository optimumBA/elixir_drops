defmodule ElixirDropsWeb.UserDropLive.BookmarksComponent do
  use ElixirDropsWeb, :live_component

  alias ElixirDrops.Bookmarks
  alias ElixirDropsWeb.DropsListHelper

  @impl Phoenix.LiveComponent
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

  @impl Phoenix.LiveComponent
  def update(%{current_user: user} = assigns, socket) do
    bookmarked_drops = Bookmarks.get_bookmarked_drops(user.id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:drops_empty?, false)
     |> assign(:end_of_timeline?, true)
     |> stream(:drops, bookmarked_drops)
     |> push_event("load_masonry", %{})}
  end
end
