defmodule ElixirDropsWeb.DropLive.Show do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Comments
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Drops
  alias ElixirDrops.Notifications
  alias ElixirDrops.StructuredData
  alias ElixirDropsWeb.Comment.FormComponent
  alias ElixirDropsWeb.CommentComponents
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.NotificationHelpers

  @consecutive_whitespace_regex ~r/\s+/
  @images_regex ~r/!\[([^\]]*)\]\([^\)]+\)/
  @links_regex ~r/\[([^\]]+)\]\(([^\)]+)\)/

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

    user = socket.assigns.current_user

    if connected?(socket) && user, do: Notifications.subscribe(user.id)

    drop = Drops.get_drop_by_short_id(short_id)

    {:noreply,
     socket
     |> assign(:end_of_notifications_timeline?, false)
     |> assign(:show_user_drops?, false)
     |> assign_drop(drop)
     |> NotificationHelpers.assign_notifications()}
  end

  @impl Phoenix.LiveView
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

  def handle_event(
        "mark_notifications_as_read",
        _params,
        %{assigns: %{current_user: user}} = socket
      ) do
    {_integer, nil} = Notifications.mark_all_as_read(user.id)

    {:noreply,
     socket
     |> stream(:notifications, [], reset: true)
     |> assign(:notification_count, 0)}
  end

  def handle_event("load-more-notifications", _params, socket),
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

  defp create_notifications(
         actor,
         drop_author,
         %Comment{parent_id: nil} = comment,
         top_level_comment_author
       ) do
    if drop_author != top_level_comment_author,
      do: create_notification(actor, drop_author, comment, %{type: :comment_on_post}),
      else: :ok
  end

  defp create_notifications(
         actor,
         drop_author,
         %Comment{parent_id: _parent_id} = comment,
         top_level_comment_author
       ) do
    if drop_author != top_level_comment_author,
      do: create_notification(actor, drop_author, comment, %{type: :comment_on_post})

    create_notification(actor, top_level_comment_author, comment, %{type: :reply_to_comment})
  end

  defp create_notification(actor, recipient, comment, attrs) do
    case Notifications.create_notification(actor, recipient, comment, attrs) do
      {:ok, notification} ->
        Notifications.broadcast_notification(notification)

      {:error, _changeset} ->
        :ok
    end
  end

  defp get_top_level_comment(%{parent_id: nil} = comment), do: Comments.get_comment!(comment.id)

  defp get_top_level_comment(%{parent_id: parent_id}),
    do: Comments.get_comment!(parent_id)

  defp create_comment(socket, params, nil) do
    Comments.create_comment(
      socket.assigns.drop,
      socket.assigns.current_user,
      nil,
      params
    )
  end

  defp create_comment(socket, params, parent_id) do
    parent_comment = Comments.get_comment!(parent_id)

    Comments.create_comment(
      socket.assigns.drop,
      socket.assigns.current_user,
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
    |> assign_comments(drop)
    |> assign_seo_attributes()
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

    description =
      drop.title
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()
      |> seo_description()

    attributes = %{
      description: description,
      image_url: get_image_url(drop),
      type: "article",
      url: url(~p"/d/#{drop.short_id}")
    }

    assign(socket, :seo_attributes, attributes)
  end

  defp get_image_url(%{screenshot: %{status: :completed, meta_url: url}}) when is_binary(url),
    do: url

  defp get_image_url(_drop), do: nil

  defp seo_description(title) do
    description =
      title
      |> remove_images()
      |> replace_links()
      |> String.trim()
      |> String.split(".")
      |> Enum.at(0)

    String.pad_trailing(description, String.length(description) + 3, ".")
  end

  defp replace_links(markdown) do
    Regex.replace(
      @links_regex,
      markdown,
      fn _other, description, _url -> description end
    )
  end

  defp remove_images(markdown) do
    @images_regex
    |> Regex.replace(markdown, "")
    |> String.replace(@consecutive_whitespace_regex, " ")
  end
end
