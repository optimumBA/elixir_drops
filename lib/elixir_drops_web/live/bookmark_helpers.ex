defmodule ElixirDropsWeb.BookmarkHelpers do
  @moduledoc false

  alias ElixirDrops.Bookmarks
  alias Phoenix.LiveView

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
          {:noreply, LiveView.push_event(socket, "remove_element", %{drop_id: drop_id})}
        else
          {:noreply,
           LiveView.push_event(socket, "show_add_bookmark_btn", %{
             add_bookmark_container_id: "add-bookmark-#{drop_id}-#{user_id}",
             remove_bookmark_container_id: "remove-bookmark-#{drop_id}-#{user_id}"
           })}
        end

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_bookmark_event(
        "bookmark_drop",
        %{"drop_id" => drop_id, "user_id" => user_id} = params,
        socket
      ) do
    case Bookmarks.create_bookmark(params) do
      {:ok, _bookmark} ->
        {:noreply,
         LiveView.push_event(socket, "show_remove_bookmark_btn", %{
           add_bookmark_container_id: "add-bookmark-#{drop_id}-#{user_id}",
           remove_bookmark_container_id: "remove-bookmark-#{drop_id}-#{user_id}"
         })}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end
end
