defmodule ElixirDropsWeb.ProfileLive.Show do
  @moduledoc """
  Public contributor profile: the GitHub identity, the Drops and Comments
  totals, and two tabs. The Drops tab lists the author's Drops with the My drops
  feed components; the Comments tab lists the author's comments and replies as
  a newest-first activity feed. Both tabs load further batches asynchronously
  on `load_more` and keep their loaded entries when switching tabs.

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

  @load_more_complete "load_more_complete"
  @comments_batch_size 10
  @comment_excerpt_length 120
  @comment_expand_length 300

  @impl Phoenix.LiveView
  def mount(%{"user_id" => user_id}, _session, socket) do
    case Accounts.get_public_user(user_id) do
      %User{} = user -> {:ok, initial_socket(socket, user)}
      nil -> raise Ecto.NoResultsError, queryable: User
    end
  end

  defp initial_socket(socket, user) do
    socket
    |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
    |> stream_configure(:comment_activity, dom_id: &"profile-comment-#{&1.id}")
    |> stream(:drops, [])
    |> stream(:comment_activity, [])
    |> assign(:batch_size, 15)
    |> assign(:batch_status, :ready)
    |> assign(:comments_batch_size, @comments_batch_size)
    |> assign(:comments_cursor, nil)
    |> assign(:comments_empty?, true)
    |> assign(:comments_end?, false)
    |> assign(:comments_loaded?, false)
    |> assign(:comments_status, :ready)
    |> assign(:comments_total, Comments.count_user_comments(user.id))
    |> assign(:drop_filters, %{user_id: user.id})
    |> assign(:drops_empty?, true)
    |> assign(:drops_loaded?, false)
    |> assign(:drops_total, Drops.count_user_drops(user.id))
    |> assign(:end_of_notifications_timeline?, false)
    |> assign(:end_of_timeline?, false)
    |> assign(:loading_more, false)
    |> assign(:page, 1)
    |> assign(:search_query, "")
    |> assign(:tab, :drops)
    |> assign(:user, user)
    |> assign(:viewport_height, nil)
    |> assign(:viewport_width, nil)
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
     |> cancel_async(:load_comments_batch)
     |> assign(:batch_status, :ready)
     |> assign(:loading_more, false)
     |> maybe_reset_interrupted_comments_batch()
     |> assign(:tab, tab)
     |> assign(:page_title, "ElixirDrops | #{socket.assigns.user.github_username}")
     |> maybe_load_tab(tab, params)}
  end

  # The Drops tab is the default; a contributor without Drops opens on Comments.
  defp tab_for(:drops, _drops_total), do: :drops
  defp tab_for(:comments, _drops_total), do: :comments
  defp tab_for(_index, 0), do: :comments
  defp tab_for(_index, _drops_total), do: :drops

  # A comments batch interrupted by leaving the tab is cancelled with its
  # cursor untouched, so the same batch is requested again on return.
  defp maybe_reset_interrupted_comments_batch(%{assigns: %{comments_status: :loading}} = socket),
    do: assign(socket, :comments_status, :ready)

  defp maybe_reset_interrupted_comments_batch(socket), do: socket

  defp maybe_load_tab(socket, :comments, _params) do
    if socket.assigns.comments_loaded? do
      socket
    else
      comments = Comments.list_user_comments(socket.assigns.user.id, limit: @comments_batch_size)
      cursor = List.last(comments)

      socket
      |> stream(:comment_activity, comments, reset: true)
      |> assign(:comments_cursor, cursor)
      |> assign(:comments_empty?, comments == [])
      |> assign(:comments_end?, length(comments) < @comments_batch_size)
      |> assign(:comments_loaded?, true)
      |> assign(:comments_status, :ready)
    end
  end

  defp maybe_load_tab(socket, :drops, params) do
    search_query = search_query(params)
    previous_query = socket.assigns.search_query

    socket =
      socket
      |> assign(:navbar_search_query, "")
      |> assign(:search_query, search_query)
      |> assign(:searching, search_query != "")

    if socket.assigns.drops_loaded? and search_query == previous_query do
      socket
    else
      base_filters = %{user_id: socket.assigns.user.id}

      filters =
        if search_query == "",
          do: base_filters,
          else: Map.put(base_filters, :search, search_query)

      socket
      |> assign(:drop_filters, filters)
      |> DropsListHelper.assign_first_batch()
      |> assign(:drops_loaded?, true)
      |> maybe_notify_feed_reset()
    end
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
    if connected?(socket), do: push_event(socket, @load_more_complete, %{}), else: socket
  end

  @impl Phoenix.LiveView
  def handle_event(
        "load_more",
        _params,
        %{assigns: %{tab: :drops, batch_status: :ready, end_of_timeline?: false}} = socket
      ) do
    {:noreply, start_batch(socket)}
  end

  def handle_event(
        "load_more",
        _params,
        %{assigns: %{tab: :comments, comments_status: :ready, comments_end?: false}} = socket
      ) do
    {:noreply, start_comments_batch(socket)}
  end

  def handle_event("load_more", _params, socket), do: {:noreply, socket}

  def handle_event(
        "retry_load_more",
        _params,
        %{assigns: %{tab: :drops, batch_status: :failed}} = socket
      ) do
    {:noreply, start_batch(socket)}
  end

  def handle_event(
        "retry_load_more",
        _params,
        %{assigns: %{tab: :comments, comments_status: :failed}} = socket
      ) do
    {:noreply, start_comments_batch(socket)}
  end

  def handle_event("retry_load_more", _params, socket), do: {:noreply, socket}

  # The browser hook asks for the entries it had loaded before a tab switch or
  # a visit to a Drop and Back; they are fetched in one bounded query and
  # streamed back in their saved order, then the hook restores the position.
  def handle_event(
        "restore_profile_feed",
        %{"tab" => "comments", "ids" => ids, "anchor" => anchor},
        %{assigns: %{tab: :comments}} = socket
      ) do
    row_ids = cast_ids(ids)
    comments = Comments.list_user_comments_by_ids(socket.assigns.user.id, row_ids)
    restored_count = length(comments)
    cursor = List.last(comments)

    {:noreply,
     socket
     |> stream(:comment_activity, comments, reset: true)
     |> assign(:comments_cursor, cursor)
     |> assign(:comments_empty?, comments == [])
     |> assign(:comments_end?, restored_count >= socket.assigns.comments_total)
     |> assign(:comments_loaded?, true)
     |> assign(:comments_status, :ready)
     |> push_event("profile_feed_restored", %{tab: "comments", anchor: anchor})}
  end

  def handle_event(
        "restore_profile_feed",
        %{"tab" => "drops", "ids" => ids, "anchor" => anchor},
        %{assigns: %{tab: :drops, search_query: ""}} = socket
      ) do
    row_ids = cast_ids(ids)

    drops =
      row_ids
      |> Drops.list_drops_by_ids()
      |> DropsListHelper.mark_saved(socket)

    restored_count = length(drops)
    last_drop = List.last(drops)
    page = restored_page(restored_count, socket.assigns.batch_size)

    {:noreply,
     socket
     |> stream(:drops, drops, reset: true)
     |> assign(:drops_empty?, drops == [])
     |> assign(:drops_loaded?, true)
     |> assign(:end_of_timeline?, restored_count >= socket.assigns.drops_total)
     |> assign(:last_drop, last_drop)
     |> assign(:page, page)
     |> push_event("profile_feed_restored", %{tab: "drops", anchor: anchor})}
  end

  def handle_event("restore_profile_feed", _params, socket), do: {:noreply, socket}

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

  # The hook saves stream dom ids; the row id is the uuid after the prefix.
  defp restored_page(count, batch_size) do
    pages = div(count - 1, batch_size) + 1
    max(1, pages)
  end

  defp cast_ids(ids) do
    for id <- ids,
        {:ok, uuid} <- [
          id
          |> String.replace_prefix("profile-comment-", "")
          |> String.replace_prefix("drop-", "")
          |> Ecto.UUID.cast()
        ],
        do: uuid
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

  defp start_comments_batch(socket) do
    user_id = socket.assigns.user.id
    cursor = socket.assigns.comments_cursor

    socket
    |> assign(:comments_status, :loading)
    |> start_async(:load_comments_batch, fn ->
      Comments.list_user_comments(user_id, limit: @comments_batch_size, older_than: cursor)
    end)
  end

  @impl Phoenix.LiveView
  def handle_async(:load_batch, {:ok, {batch_size, {:ok, drops}}}, socket) do
    {:noreply,
     socket
     |> DropsListHelper.apply_batch(drops, batch_size)
     |> assign(:batch_status, :ready)
     |> push_event(@load_more_complete, %{})}
  end

  def handle_async(:load_batch, {:exit, {:shutdown, :cancel}}, socket) do
    {:noreply, socket}
  end

  def handle_async(:load_batch, _failure, socket) do
    {:noreply,
     socket
     |> assign(:batch_status, :failed)
     |> assign(:loading_more, false)}
  end

  def handle_async(:load_comments_batch, {:ok, comments}, socket) do
    {:noreply,
     socket
     |> stream(:comment_activity, comments)
     |> assign(:comments_cursor, List.last(comments) || socket.assigns.comments_cursor)
     |> assign(:comments_end?, length(comments) < @comments_batch_size)
     |> assign(:comments_status, :ready)
     |> push_event(@load_more_complete, %{})}
  end

  # Leaving the tab cancels the in-flight batch; its cursor is untouched and
  # `handle_params` already reset the status, so the cancelled exit is ignored
  # and the same batch is requested again on return.
  def handle_async(:load_comments_batch, {:exit, {:shutdown, :cancel}}, socket) do
    {:noreply, socket}
  end

  def handle_async(:load_comments_batch, _failure, socket) do
    {:noreply, assign(socket, :comments_status, :failed)}
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

  # Presentational expand/collapse for long comments. Runs inline so it works
  # on the static render before the app bundle executes; app.js re-applies the
  # expanded state when LiveView replaces stream entries on join/restore.
  defp comment_expand_script do
    """
    <script>
    (function () {
      if (window.__profileExpandBound) return;
      window.__profileExpandBound = true;
      var expanded = (window.__expandedComments = window.__expandedComments || new Set());
      document.addEventListener('click', function (event) {
        var button = event.target.closest('[data-profile-expand]');
        if (!button) return;
        var body = document.getElementById(button.getAttribute('aria-controls'));
        if (!body) return;
        var ex = button.getAttribute('aria-expanded') !== 'true';
        button.setAttribute('aria-expanded', String(ex));
        body.classList.toggle('max-h-48', !ex);
        body.classList.toggle('overflow-hidden', !ex);
        var more = button.querySelector('[data-comment-more]');
        var less = button.querySelector('[data-comment-less]');
        if (more) more.classList.toggle('hidden', ex);
        if (less) less.classList.toggle('hidden', !ex);
        ex ? expanded.add(body.id) : expanded.delete(body.id);
      });
    })();
    </script>
    """
  end

  defp comments_feed_state(%{comments_status: :loading}), do: "loading"
  defp comments_feed_state(%{comments_status: :failed}), do: "retry"
  defp comments_feed_state(%{comments_empty?: true}), do: "empty"
  defp comments_feed_state(%{comments_end?: true}), do: "exhausted"
  defp comments_feed_state(_assigns), do: "idle"

  defp total_label(1, singular), do: singular
  defp total_label(_count, singular), do: singular <> "s"

  defp tab_class(active?) do
    [
      "min-h-full py-4 border-b-2 flex items-center mr-8",
      (active? && "border-b-[#887ce1]") || "border-b-transparent hover:border-b-gray-300"
    ]
  end

  defp long_comment?(body), do: String.length(body) > @comment_expand_length

  defp maybe_parent_excerpt(body) do
    if String.length(body) > @comment_excerpt_length do
      String.slice(body, 0, @comment_excerpt_length) <> "…"
    else
      body
    end
  end

  defp comment_date(inserted_at), do: Calendar.strftime(inserted_at, "%b %-d, %Y")

  defp discussion_path(%{parent_id: nil} = comment),
    do: ~p"/d/#{comment.drop.short_id}?comment_id=#{comment.id}"

  defp discussion_path(comment),
    do:
      ~p"/d/#{comment.drop.short_id}?comment_parent_id=#{comment.parent_id}&comment_id=#{comment.id}"
end
