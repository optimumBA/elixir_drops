defmodule ElixirDropsWeb.BookmarkHelpers do
  @moduledoc false

  alias ElixirDrops.Bookmarks
  alias ElixirDrops.Drops

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
        drop = Drops.get_drop(%{drop_id: drop_id})

        bookmark_tab? = Map.get(socket.assigns, :bookmark_tab?)

        if bookmark_tab?,
          do: {:noreply, Phoenix.LiveView.stream_delete(socket, :drops, drop)},
          else: {:noreply, Phoenix.LiveView.stream_insert(socket, :drops, drop)}

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
        drop = Drops.get_drop(%{drop_id: drop_id})
        {:noreply, Phoenix.LiveView.stream_insert(socket, :drops, drop)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end
end
