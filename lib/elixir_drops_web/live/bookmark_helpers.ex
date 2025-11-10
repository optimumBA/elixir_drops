defmodule ElixirDropsWeb.BookmarkHelpers do
  @moduledoc false

  alias ElixirDrops.Bookmarks

  @type event :: String.t()
  @type params :: map()
  @type socket :: Phoenix.LiveView.Socket.t()

  @spec handle_bookmark_event(event(), params(), socket()) :: {:noreply, socket()}
  def handle_bookmark_event(
        "remove_from_bookmark",
        %{"drop_id" => drop_id, "user_id" => user_id},
        socket
      ) do
    bookmark = Bookmarks.get_bookmark(drop_id, user_id)

    case Bookmarks.delete_bookmark(bookmark) do
      {:ok, _bookmark} ->
        bookmark_tab? = Map.get(socket.assigns, :bookmark_tab?)

        if bookmark_tab? do
          socket = Phoenix.LiveView.push_event(socket, "remove_element", %{drop_id: drop_id})
          {:noreply, socket}
        else
          {:noreply, socket}
        end

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_bookmark_event(
        "bookmark_drop",
        %{"drop_id" => drop_id, "user_id" => user_id},
        socket
      ) do
    Bookmarks.create_bookmark(drop_id, user_id)

    {:noreply, socket}
  end
end
