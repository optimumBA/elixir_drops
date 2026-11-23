defmodule ElixirDropsWeb.BookmarkLive.Index do
  @moduledoc """
  The signed-in account's private Bookmarks list: its saved Drops as the shared
  Drop cards, most recently saved first, loaded in batches on the `load_more`
  event of the infinite-scroll marker.

  The list is always the viewing account's own; there is no way to address
  another account's bookmarks.
  """

  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDrops.Notifications
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropsListHelper
  alias ElixirDropsWeb.NotificationHelpers

  @batch_size 10
  @type socket :: Phoenix.LiveView.Socket.t()
  @type uuid :: Ecto.UUID.t()

  @load_more_complete "load_more_complete"

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
     |> stream(:drops, [])
     |> assign(:batch_size, @batch_size)
     |> assign(:bookmarks_empty?, true)
     |> assign(:drops_empty?, true)
     |> assign(:end_of_notifications_timeline?, false)
     |> assign(:end_of_timeline?, false)
     |> assign(:last_drop, nil)
     |> assign(:loaded_ids, MapSet.new())
     |> assign(:loading_more, false)
     |> assign(:page, 1)
     |> assign(:page_title, "ElixirDrops | Bookmarks")
     |> assign(:viewport_height, nil)
     |> assign(:viewport_width, nil)}
  end

  @impl Phoenix.LiveView
  def on_connect(socket) do
    Notifications.subscribe(socket.assigns.current_user.id)
    super(socket)
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _url, socket) do
    batch_size = socket.assigns.batch_size
    drops = list_batch(socket, nil)

    {:noreply,
     socket
     |> stream(:drops, drops, reset: true)
     |> assign(:drops_empty?, drops == [])
     |> assign(:end_of_timeline?, length(drops) < batch_size)
     |> assign(:last_drop, List.last(drops))
     |> assign(:loaded_ids, MapSet.new(drops, & &1.id))
     |> assign(:page, 1)
     |> refresh_empty_state()}
  end

  @impl Phoenix.LiveView
  def handle_event("load_more", _params, %{assigns: %{end_of_timeline?: false}} = socket) do
    batch_size = socket.assigns.batch_size
    drops = list_batch(socket, socket.assigns.last_drop)

    {:noreply,
     socket
     |> stream(:drops, drops)
     |> assign(:end_of_timeline?, length(drops) < batch_size)
     |> assign(:last_drop, List.last(drops) || socket.assigns.last_drop)
     |> update(:loaded_ids, &Enum.reduce(drops, &1, fn drop, ids -> MapSet.put(ids, drop.id) end))
     |> assign(:page, socket.assigns.page + 1)
     |> refresh_empty_state()
     |> push_event(@load_more_complete, %{})}
  end

  def handle_event("load_more", _params, socket), do: {:noreply, socket}

  def handle_event("load_more_complete", _params, socket), do: {:noreply, socket}

  def handle_event("load_more_notifications", _params, socket),
    do: NotificationHelpers.load_more(socket)

  def handle_event("navbar_search_submit", %{"query" => query}, socket) do
    case String.trim(query) do
      "" -> {:noreply, push_navigate(socket, to: ~p"/")}
      trimmed -> {:noreply, push_navigate(socket, to: ~p"/?q=#{trimmed}")}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  def handle_info(
        {:new_notification, notification},
        %{assigns: %{notification_count: count}} = socket
      ) do
    {:noreply,
     socket
     |> assign(:notification_count, count + 1)
     |> stream_insert(:notifications, notification, at: 0)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @doc """
  Forgets a Drop removed from the list; with nothing left to show the empty
  state appears.
  """
  @spec forget(socket(), uuid()) :: socket()
  def forget(socket, drop_id) do
    socket
    |> update(:loaded_ids, &MapSet.delete(&1, drop_id))
    |> refresh_empty_state()
  end

  # Nothing is shown and nothing more can be loaded.
  defp refresh_empty_state(socket) do
    %{loaded_ids: ids, end_of_timeline?: end?} = socket.assigns
    assign(socket, :bookmarks_empty?, end? and MapSet.size(ids) == 0)
  end

  defp list_batch(socket, older_than) do
    %{current_user: user, batch_size: batch_size} = socket.assigns
    Drops.list_bookmarked_drops(user.id, batch_size, older_than)
  end
end
