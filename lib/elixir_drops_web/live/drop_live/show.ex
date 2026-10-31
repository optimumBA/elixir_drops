defmodule ElixirDropsWeb.DropLive.Show do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Comments
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Drops
  alias ElixirDrops.Notifications
  alias ElixirDrops.Sponsors
  alias ElixirDrops.StructuredData
  alias ElixirDropsWeb.Comment.FormComponent
  alias ElixirDropsWeb.CommentComponents
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.NotificationHelpers

  @images_regex ~r/!\[([^\]]*)\]\([^\)]+\)/
  @links_regex ~r/\[([^\]]+)\]\(([^\)]+)\)/
  @code_blocks_regex ~r/```[\s\S]*?```/
  @html_tags_regex ~r/<[^>]*>/
  @description_max_length 160

  # Connection-only work lives here: on a resumed warm connect mount/3 and
  # handle_params/3 are skipped, so subscribing in handle_params/3 behind
  # connected?/1 would never run (the dead render had connected? == false).
  # on_connect/1 fires once per live connection. See drop_live/index.ex.
  # Capture connect info here; LiveView removes it before handle_event/3.
  @impl Phoenix.LiveView
  def on_connect(socket) do
    user = socket.assigns.current_user
    if user, do: Notifications.subscribe(user.id)

    socket = assign(socket, :sponsor_impression_user_agent, get_connect_info(socket, :user_agent))

    super(socket)
  end

  @impl Phoenix.LiveView
  def handle_params(%{"short_id" => short_id} = params, _url, socket) do
    comment_id = params["comment_id"]
    parent_id = params["comment_parent_id"] || ""

    socket =
      if comment_id do
        push_event(socket, "show_comment", %{
          comment_id: comment_id,
          parent_id: parent_id
        })
      else
        socket
      end

    drop = Drops.get_drop_by_short_id(short_id)

    {:noreply,
     socket
     |> assign(:end_of_notifications_timeline?, false)
     |> assign(:show_user_drops?, false)
     |> assign_drop(drop)}
  end

  @impl Phoenix.LiveView
  def handle_event(event, params, socket)
      when event in ["sponsor_impression", "sponsor_visible_impression"] do
    drop = socket.assigns[:drop]

    if drop && params["drop_id"] == drop.short_id do
      kind = if event == "sponsor_impression", do: "impression", else: "visible_impression"

      {acknowledged, socket} =
        record_sponsor_impressions(socket, drop, sponsor_placements(params), kind)

      {:reply, %{acknowledged: acknowledged}, socket}
    else
      {:reply, %{acknowledged: []}, socket}
    end
  end

  def handle_event("navbar_search_submit", %{"query" => query}, socket) do
    trimmed_query = String.trim(query)

    if trimmed_query != "" do
      {:noreply, push_navigate(socket, to: ~p"/?q=#{trimmed_query}")}
    else
      {:noreply, push_navigate(socket, to: ~p"/")}
    end
  end

  def handle_event(
        "delete_comment",
        %{"comment_id" => comment_id},
        %{assigns: %{drop: drop}} = socket
      ) do
    comment = Comments.get_comment!(comment_id)
    Comments.delete_comment(comment_id)
    comment_count = Comments.count_drop_comments(drop.id)

    socket = assign(socket, :comment_count, comment_count)

    if comment.parent_id do
      comment = get_top_level_comment(comment)
      {:noreply, stream_insert(socket, :comments, comment)}
    else
      {:noreply, stream_delete(socket, :comments, comment)}
    end
  end

  def handle_event(
        "load_more",
        %{"offset" => offset},
        %{
          assigns: %{
            drop: drop
          }
        } = socket
      ) do
    comments = Comments.list_drop_comments(drop.id, offset: offset)

    {:noreply,
     socket
     |> assign(:comment_offset, offset + 10)
     |> stream(:comments, comments)}
  end

  def handle_event("load_more_notifications", _params, socket),
    do: NotificationHelpers.load_more(socket)

  @impl Phoenix.LiveView
  def handle_info({:new_comment, parent_id, comment_type, comment_params}, socket) do
    case create_comment(socket, comment_params, parent_id) do
      {:ok, comment} ->
        top_level_comment = get_top_level_comment(comment)
        changeset = Comments.change_comment(%Comment{})
        comment_count = socket.assigns.comment_count + 1

        if is_nil(parent_id) and comment_type == :comment,
          do:
            send_update(FormComponent,
              id: "new-comment-form",
              form: to_form(changeset)
            )

        %{assigns: %{current_user: user, drop: %{user: drop_author}}} = socket
        create_notifications(user, drop_author, comment, top_level_comment.user)

        {:noreply,
         socket
         |> assign(:comment_count, comment_count)
         |> stream_insert(:comments, top_level_comment, at: 0)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add your comment")}
    end
  end

  def handle_info({:update_comment, comment, params}, socket) do
    case Comments.update_comment(comment, params) do
      {:ok, comment} ->
        {:noreply, stream_insert(socket, :comments, get_top_level_comment(comment))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update comment")}
    end
  end

  def handle_info(
        {:new_notification, notification},
        %{assigns: %{notification_count: count}} = socket
      ) do
    {:noreply,
     socket
     |> assign(:notification_count, count + 1)
     |> stream_insert(:notifications, notification, at: 0)}
  end

  # Successful/skipped placements are acknowledged separately per metric. IDs
  # originate here and remain stable for retries; client IDs are never accepted.
  defp record_sponsor_impressions(socket, drop, placements, kind) do
    measurements = socket.assigns[:sponsor_measurements] || %{}
    key = {drop.id, kind}
    state = Map.get(measurements, key, %{seen: [], ids: %{}})
    {already, pending} = Enum.split_with(placements, &(&1 in state.seen))

    ids = sponsor_event_ids(pending, state.ids)
    opts = sponsor_impression_options(socket, ids)
    results = record_sponsor_metric(kind, pending, opts)

    handled = for {placement, status} <- results, status in [:persisted, :skipped], do: placement
    updated_measurements = Map.put(measurements, key, %{seen: state.seen ++ handled, ids: ids})
    {already ++ handled, assign(socket, :sponsor_measurements, updated_measurements)}
  end

  defp sponsor_event_ids(pending, ids) do
    Enum.reduce(pending, ids, &Map.put_new_lazy(&2, &1, fn -> Sponsors.new_event_id() end))
  end

  defp sponsor_impression_options(socket, ids) do
    [
      user: socket.assigns[:current_user],
      user_agent: socket.assigns[:sponsor_impression_user_agent],
      event_ids: ids
    ]
  end

  defp record_sponsor_metric("impression", pending, opts),
    do: Sponsors.record_impression_results(pending, opts)

  defp record_sponsor_metric("visible_impression", pending, opts),
    do: Sponsors.record_visible_impression_results(pending, opts)

  defp sponsor_placements(%{"placements" => placements}) when is_list(placements) do
    placements
    |> Enum.filter(&(&1 in Sponsors.placements()))
    |> Enum.uniq()
  end

  defp sponsor_placements(_params), do: []

  defp create_notifications(
         actor,
         drop_author,
         %Comment{parent_id: parent_id} = comment,
         top_level_comment_author
       ) do
    if parent_id do
      create_notification(actor, top_level_comment_author, comment, %{type: :reply_to_comment})
    end

    notify_drop_author(actor, drop_author, comment, top_level_comment_author)
  end

  defp notify_drop_author(actor, drop_author, comment, top_level_comment_author)
       when drop_author != top_level_comment_author do
    create_notification(actor, drop_author, comment, %{type: :comment_on_post})
  end

  defp notify_drop_author(_actor, _drop_author, _comment, _top_level_comment_author), do: :ok

  defp create_notification(actor, recipient, comment, attrs) do
    case Notifications.create_notification(actor, recipient, comment, attrs) do
      {:ok, notification} ->
        Notifications.broadcast(notification)

      {:error, _changeset} ->
        :ok
    end
  end

  defp get_top_level_comment(%{parent_id: nil} = comment), do: Comments.get_comment!(comment.id)

  defp get_top_level_comment(%{parent_id: parent_id}),
    do: Comments.get_comment!(parent_id)

  defp create_comment(%{assigns: %{drop: drop, current_user: user}} = _socket, params, nil) do
    Comments.create_comment(
      drop,
      user,
      nil,
      params
    )
  end

  defp create_comment(%{assigns: %{drop: drop, current_user: user}} = _socket, params, parent_id) do
    parent_comment = Comments.get_comment!(parent_id)

    Comments.create_comment(
      drop,
      user,
      parent_comment,
      params
    )
  end

  defp assign_drop(socket, nil) do
    socket
    |> assign(:drop, nil)
    |> push_patch(to: ~p"/")
  end

  defp assign_drop(socket, drop) do
    title =
      drop.title
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()

    socket
    |> assign(:drop, drop)
    |> assign(:page_title, title)
    |> assign_seo_attributes()
    |> assign_comments(drop)
  end

  defp assign_comments(socket, drop) do
    top_level_comment_count = Comments.count_drop_top_level_comments(drop.id)

    comments = Comments.list_drop_comments(drop.id)

    socket
    |> assign(:comment_count, drop.comment_count)
    |> assign(:comment_offset, 10)
    |> assign(:top_level_comment_count, top_level_comment_count)
    |> stream(:comments, comments, reset: true)
  end

  defp assign_seo_attributes(socket) do
    %{drop: drop} = socket.assigns

    description = seo_description(drop)

    attributes = %{
      description: description,
      image_url: get_image_url(drop),
      type: "article",
      canonical_url: url(~p"/d/#{drop.short_id}"),
      url: url(~p"/d/#{drop.short_id}")
    }

    assign(socket, :seo_attributes, attributes)
  end

  defp get_image_url(%{screenshot: %{status: :completed, meta_url: url}}) when is_binary(url),
    do: url

  defp get_image_url(_drop), do: nil

  defp seo_description(drop) do
    title = plain_text(drop.title)
    summary = plain_text(drop.body)

    description =
      case summary do
        "" -> title
        _summary -> title <> " — " <> summary
      end

    if String.length(description) > @description_max_length do
      String.slice(description, 0, @description_max_length - 3) <> "..."
    else
      description
    end
  end

  defp plain_text(markdown) do
    markdown
    |> remove_code_blocks()
    |> remove_images()
    |> replace_links()
    |> remove_html_tags()
    |> String.replace(~r/`([^`]+)`/, "\\1")
    |> String.replace(~r/(\*\*|__)(.*?)\1/, "\\2")
    |> String.replace(~r/(?<!\w)\*([^\*]+)\*(?!\w)/, "\\1")
    |> String.replace(~r/(?<!\w)_([^_]+)_(?!\w)/, "\\1")
    |> String.replace("~~", "")
    |> String.replace(~r/^\s{0,3}#+\s+/m, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp replace_links(markdown) do
    Regex.replace(@links_regex, markdown, fn _match, description, _url -> description end)
  end

  defp remove_images(markdown) do
    Regex.replace(@images_regex, markdown, "")
  end

  defp remove_code_blocks(markdown), do: Regex.replace(@code_blocks_regex, markdown, " ")

  defp remove_html_tags(markdown), do: Regex.replace(@html_tags_regex, markdown, " ")
end
