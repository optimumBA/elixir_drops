defmodule ElixirDropsWeb.ProfileLive.Show do
  @moduledoc """
  Public contributor profile: the GitHub identity, the Drops and Comments
  totals, and two tabs. The Drops tab lists the author's Drops with the My drops
  feed components and loads further batches asynchronously on `load_more`; the
  Comments tab only carries a notice until the comment activity feed exists.

  Everything shown is public and identical for every viewer.
  """

  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Accounts
  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Comments
  alias ElixirDrops.Drops
  alias ElixirDrops.Notifications
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropsListHelper
  alias ElixirDropsWeb.NotificationHelpers
  alias ElixirDropsWeb.SearchHelper

  @impl Phoenix.LiveView
  def mount(%{"user_id" => user_id}, _session, socket) do
    case Accounts.get_public_user(user_id) do
      %User{} = user ->
        {:ok,
         socket
         |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
         |> assign(:batch_size, 15)
         |> assign(:batch_status, :ready)
         |> assign(:comments_total, Comments.count_user_comments(user.id))
         |> assign(:drop_filters, %{user_id: user.id})
         |> assign(:drops_empty?, true)
         |> assign(:drops_total, Drops.count_user_drops(user.id))
         |> assign(:end_of_notifications_timeline?, false)
         |> assign(:end_of_timeline?, false)
         |> assign(:loading_more, false)
         |> assign(:page, 1)
         |> assign(:search_query, "")
         |> assign(:tab, :drops)
         |> assign(:user, user)
         |> assign(:viewport_height, nil)
         |> assign(:viewport_width, nil)}

      nil ->
        raise Ecto.NoResultsError, queryable: User
    end
  end

  @impl Phoenix.LiveView
  def on_connect(socket) do
    if user = socket.assigns.current_user, do: Notifications.subscribe(user.id)
    super(socket)
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    tab = tab_for(socket.assigns.live_action, socket.assigns.drops_total)

    {:noreply,
     socket
     |> cancel_async(:load_batch)
     |> assign(:tab, tab)
     |> assign(:page_title, "ElixirDrops | #{socket.assigns.user.github_username}")
     |> load_tab(tab, params)}
  end

  # The Drops tab is the default; a contributor without Drops opens on Comments.
  defp tab_for(:drops, _drops_total), do: :drops
  defp tab_for(:comments, _drops_total), do: :comments
  defp tab_for(_index, 0), do: :comments
  defp tab_for(_index, _drops_total), do: :drops

  defp load_tab(socket, :comments, _params), do: assign(socket, :batch_status, :ready)

  defp load_tab(socket, :drops, params) do
    search_query = search_query(params)
    base_filters = %{user_id: socket.assigns.user.id}

    filters =
      if search_query == "", do: base_filters, else: Map.put(base_filters, :search, search_query)

    socket
    |> assign(:batch_status, :ready)
    |> assign(:drop_filters, filters)
    |> assign(:navbar_search_query, "")
    |> assign(:search_query, search_query)
    |> assign(:searching, search_query != "")
    |> DropsListHelper.assign_first_batch()
    |> maybe_notify_feed_reset()
  end

  defp search_query(%{"q" => query}) when is_binary(query), do: trimmed(query)
  defp search_query(_params), do: ""

  defp trimmed(query) do
    query
    |> to_string()
    |> String.trim()
  end

  # A new feed lets the scroll hook leave a pending or failed state from the
  # previous one and re-check whether the page needs more.
  defp maybe_notify_feed_reset(socket) do
    if connected?(socket), do: push_event(socket, "load_more_complete", %{}), else: socket
  end

  @impl Phoenix.LiveView
  def handle_event(
        "load_more",
        _params,
        %{assigns: %{tab: :drops, batch_status: :ready, end_of_timeline?: false}} = socket
      ) do
    {:noreply, start_batch(socket)}
  end

  def handle_event("load_more", _params, socket), do: {:noreply, socket}

  def handle_event("retry_load_more", _params, %{assigns: %{batch_status: :failed}} = socket) do
    {:noreply, start_batch(socket)}
  end

  def handle_event("retry_load_more", _params, socket), do: {:noreply, socket}

  def handle_event("profile_search_submit", %{"query" => query}, socket) do
    path = ~p"/u/#{socket.assigns.user.id}/drops"

    case trimmed(query) do
      "" -> {:noreply, push_patch(socket, to: path)}
      trimmed -> {:noreply, push_patch(socket, to: "#{path}?#{URI.encode_query(q: trimmed)}")}
    end
  end

  def handle_event("load_more_notifications", _params, socket),
    do: NotificationHelpers.load_more(socket)

  def handle_event("navbar_search_submit", %{"query" => query}, socket) do
    SearchHelper.track_search(query, socket, %{})
    {:noreply, navigate_to_home_search(socket, query)}
  end

  def handle_event("search_submit", %{"query" => query}, socket) do
    {:noreply, navigate_to_home_search(socket, query)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp navigate_to_home_search(socket, query) do
    case trimmed(query) do
      "" -> push_navigate(socket, to: ~p"/")
      trimmed -> push_navigate(socket, to: ~p"/?q=#{trimmed}")
    end
  end

  # The batch is fetched in a task so the page can show it as loading, and a failed
  # fetch leaves the cursor where it was: the same batch is requested again.
  defp start_batch(socket) do
    {filters, batch_size} = DropsListHelper.next_batch_request(socket)

    socket
    |> assign(:batch_status, :loading)
    |> assign(:loading_more, true)
    |> start_async(:load_batch, fn -> {batch_size, Drops.fetch_drops(filters, batch_size)} end)
  end

  @impl Phoenix.LiveView
  def handle_async(:load_batch, {:ok, {batch_size, {:ok, drops}}}, socket) do
    {:noreply,
     socket
     |> DropsListHelper.apply_batch(drops, batch_size)
     |> assign(:batch_status, :ready)
     |> push_event("load_more_complete", %{})}
  end

  def handle_async(:load_batch, _failure, socket) do
    {:noreply,
     socket
     |> assign(:batch_status, :failed)
     |> assign(:loading_more, false)}
  end

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

  defp feed_state(%{batch_status: :loading}), do: "loading"
  defp feed_state(%{batch_status: :failed}), do: "retry"
  defp feed_state(%{drops_empty?: true}), do: "empty"
  defp feed_state(%{end_of_timeline?: true}), do: "exhausted"
  defp feed_state(_assigns), do: "idle"

  defp total_label(1, singular), do: singular
  defp total_label(_count, singular), do: singular <> "s"

  defp tab_class(active?) do
    [
      "min-h-full py-4 border-b-2 flex items-center mr-8",
      (active? && "border-b-[#887ce1]") || "border-b-transparent hover:border-b-gray-300"
    ]
  end
end
