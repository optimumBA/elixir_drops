defmodule ElixirDropsWeb.BookmarkHelpers do
  @moduledoc false

  import Phoenix.Component

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
        {:noreply, assign(socket, :bookmarked?, false)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_bookmark_event(
        "bookmark_drop",
        %{"drop_id" => drop_id, "user_id" => user_id},
        socket
      ) do
    case Bookmarks.create_bookmark(drop_id, user_id) do
      {:ok, _bookmark} ->
        {:noreply, assign(socket, :bookmarked?, true)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end
end
