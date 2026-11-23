defmodule ElixirDropsWeb.BookmarkEvents do
  @moduledoc """
  The shared Bookmark action: one handler for every page that shows the control.

  A signed-in viewer's `toggle_bookmark` event saves or removes a Drop and the
  page reflects the new state: the card in a feed is updated in place (or removed
  from the Bookmarks list), the Drop page updates its control and aggregate count.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [stream_delete: 3, stream_insert: 4]

  alias ElixirDrops.Bookmarks
  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDropsWeb.BookmarkLive

  @type socket :: Phoenix.LiveView.Socket.t()
  @type text :: String.t()
  @type uuid :: Ecto.UUID.t()

  @doc """
  Saves (`saved?` true) or removes the Drop for the account and updates the page.
  """
  @spec apply(socket(), uuid(), text(), boolean()) :: socket()
  def apply(socket, user_id, drop_id, saved?) do
    with {:ok, drop_id} <- Ecto.UUID.cast(drop_id),
         :ok <- persist(user_id, drop_id, saved?) do
      maybe_refresh(socket, drop_id, saved?)
    else
      _unknown_drop -> socket
    end
  end

  defp persist(user_id, drop_id, true), do: Bookmarks.save_bookmark(user_id, drop_id)
  defp persist(user_id, drop_id, false), do: Bookmarks.remove_bookmark(user_id, drop_id)

  defp maybe_refresh(
         %{view: ElixirDropsWeb.DropLive.Show, assigns: %{drop: %Drop{id: id} = drop}} = socket,
         id,
         saved?
       ) do
    socket
    |> assign(:drop, %{drop | bookmarked: saved?})
    |> assign(:bookmark_count, Bookmarks.count_drop_bookmarks(id))
  end

  defp maybe_refresh(%{view: ElixirDropsWeb.DropLive.Show} = socket, _drop_id, _saved?),
    do: socket

  defp maybe_refresh(%{view: ElixirDropsWeb.BookmarkLive.Index} = socket, drop_id, false) do
    socket
    |> stream_delete(:drops, %Drop{id: drop_id})
    |> BookmarkLive.Index.forget(drop_id)
  end

  defp maybe_refresh(socket, drop_id, saved?) do
    case Drops.get_drop(%{drop_id: drop_id}) do
      nil -> socket
      drop -> stream_insert(socket, :drops, %{drop | bookmarked: saved?}, update_only: true)
    end
  end
end
