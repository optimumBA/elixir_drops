defmodule ElixirDropsWeb.DropLive.Show do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Comments
  alias ElixirDrops.Drops
  alias ElixirDrops.StructuredData
  alias ElixirDropsWeb.DropComponents

  @consecutive_whitespace_regex ~r/\s+/
  @images_regex ~r/!\[([^\]]*)\]\([^\)]+\)/
  @links_regex ~r/\[([^\]]+)\]\(([^\)]+)\)/

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:replying_to, nil)
     |> assign(:editing_comment, nil)
     |> stream(:comments, [])}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"short_id" => short_id}, _url, socket) do
    drop = Drops.get_drop_by_short_id(short_id)

    updated_socket =
      socket
      |> assign(:show_user_drops?, false)
      |> assign_drop(drop)

    final_socket =
      if drop do
        # Subscribe only when connected
        if connected?(updated_socket) do
          Comments.subscribe_to_drop_comments(drop.id)
        end

        # Always load comments, even for dead renders
        assign_comments(updated_socket, drop)
      else
        updated_socket
      end

    {:noreply, final_socket}
  end

  @impl Phoenix.LiveView
  def handle_event("new_comment", %{"comment" => comment_params}, socket) do
    %{drop: drop, current_user: current_user} = socket.assigns

    comment_params =
      comment_params
      |> Map.put("drop_id", drop.id)
      |> Map.put("user_id", current_user.id)

    case Comments.create_comment(comment_params) do
      {:ok, _comment} ->
        changeset = Comments.change_comment(%Comments.Comment{})
        # Don't insert directly - let PubSub broadcast handle it for all clients
        socket = assign(socket, :comment_changeset, changeset)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :comment_changeset, changeset)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("validate_comment", %{"comment" => comment_params}, socket) do
    changeset =
      %Comments.Comment{}
      |> Comments.change_comment(comment_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :comment_changeset, changeset)}
  end

  def handle_event("reply", %{"comment-id" => comment_id}, socket) do
    # When we update replying_to, we need to force re-render of stream items
    # by resetting the stream with the same data
    %{drop: drop} = socket.assigns
    comments = Comments.list_drop_comments(drop.id)

    socket =
      socket
      |> assign(:replying_to, comment_id)
      |> stream(:comments, comments, reset: true)

    {:noreply, socket}
  end

  def handle_event("cancel_reply", _params, socket) do
    %{drop: drop} = socket.assigns
    comments = Comments.list_drop_comments(drop.id)

    socket =
      socket
      |> assign(:replying_to, nil)
      |> stream(:comments, comments, reset: true)

    {:noreply, socket}
  end

  def handle_event("edit_comment_toggle", %{"comment-id" => comment_id}, socket) do
    %{drop: drop} = socket.assigns
    comments = Comments.list_drop_comments(drop.id)

    socket =
      socket
      |> assign(:editing_comment, comment_id)
      |> stream(:comments, comments, reset: true)

    {:noreply, socket}
  end

  def handle_event("cancel_edit", _params, socket) do
    %{drop: drop} = socket.assigns
    comments = Comments.list_drop_comments(drop.id)

    socket =
      socket
      |> assign(:editing_comment, nil)
      |> stream(:comments, comments, reset: true)

    {:noreply, socket}
  end

  def handle_event(
        "reply_to_comment",
        %{"comment-id" => parent_id, "comment" => comment_params},
        socket
      ) do
    %{drop: drop, current_user: current_user} = socket.assigns

    comment_params =
      comment_params
      |> Map.put("drop_id", drop.id)
      |> Map.put("user_id", current_user.id)
      |> Map.put("parent_id", parent_id)

    case Comments.create_comment(comment_params) do
      {:ok, _comment} ->
        socket =
          socket
          |> assign(:replying_to, nil)
          |> reload_comments_preserving_ui_state()

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create reply")}
    end
  end

  def handle_event(
        "update_comment",
        %{"comment-id" => comment_id, "comment" => comment_params},
        socket
      ) do
    comment = Comments.get_comment!(comment_id)

    case Comments.update_comment(comment, comment_params) do
      {:ok, _comment} ->
        socket =
          socket
          |> assign(:editing_comment, nil)
          |> reload_comments_preserving_ui_state()

        {:noreply, socket}

      {:error, changeset} ->
        # Assign the error changeset for the specific comment being edited
        socket =
          socket
          |> assign(:comment_changeset, changeset)
          |> put_flash(:error, "Failed to update comment")

        {:noreply, socket}
    end
  end

  def handle_event("delete_comment", %{"comment-id" => comment_id}, socket) do
    %{current_user: current_user} = socket.assigns
    comment = Comments.get_comment!(comment_id)

    # Check if user can delete this comment
    if comment.user_id == current_user.id do
      case Comments.delete_comment(comment) do
        {:ok, _comment} ->
          socket = reload_comments_preserving_ui_state(socket)
          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete comment")}
      end
    else
      {:noreply, put_flash(socket, :error, "You can only delete your own comments")}
    end
  end

  def handle_event("load_more_comments", _params, socket) do
    %{drop: drop} = socket.assigns

    # Count comments currently displayed to use as offset
    # Since we can't directly count stream items, we'll track this separately
    current_count =
      case socket.assigns[:loaded_comments_count] do
        # Initial load shows 10
        nil -> 10
        count -> count
      end

    new_comments = Comments.list_drop_comments(drop.id, offset: current_count)

    socket =
      socket
      |> then(fn s ->
        Enum.reduce(new_comments, s, fn comment, acc ->
          stream_insert(acc, :comments, comment, at: -1)
        end)
      end)
      |> assign(:has_more_comments, length(new_comments) >= 10)
      |> assign(:loaded_comments_count, current_count + length(new_comments))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(
        %{event: "comment_event", payload: %{event: event, comment: _comment}},
        socket
      )
      when event in [:created, :updated, :deleted] do
    # Reload all comments to handle nested replies properly
    %{drop: drop} = socket.assigns
    comments = Comments.list_drop_comments(drop.id)
    comment_count = Comments.count_drop_comments(drop.id)

    socket =
      socket
      |> stream(:comments, comments, reset: true)
      |> assign(:comment_count, comment_count)
      |> assign(:has_more_comments, length(comments) >= 10)
      |> assign(:loaded_comments_count, length(comments))

    {:noreply, socket}
  end

  def handle_info({Drops.DropsBroadcast, _event, _drop}, socket), do: {:noreply, socket}

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
    |> assign(:comment_changeset, Comments.change_comment(%Comments.Comment{}))
    |> assign(:comment_count, drop.comment_count || 0)
    |> assign(:has_more_comments, false)
    |> assign(:replying_to, nil)
    |> assign(:editing_comment, nil)
    |> assign(:page_title, title)
    |> assign_seo_attributes()
  end

  defp assign_comments(socket, drop) do
    comments = Comments.list_drop_comments(drop.id)
    comment_count = Comments.count_drop_comments(drop.id)

    socket
    |> stream(:comments, comments, reset: true)
    |> assign(:comment_count, comment_count)
    |> assign(:has_more_comments, length(comments) >= 10)
    |> assign(:loaded_comments_count, length(comments))
  end

  defp reload_comments_preserving_ui_state(socket) do
    %{drop: drop} = socket.assigns
    comments = Comments.list_drop_comments(drop.id)
    comment_count = Comments.count_drop_comments(drop.id)

    socket
    |> stream(:comments, comments, reset: true)
    |> assign(:comment_count, comment_count)
    |> assign(:has_more_comments, length(comments) >= 10)
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

  @impl Phoenix.LiveView
  def handle_event("navbar_search_submit", %{"query" => query}, socket) do
    trimmed_query = String.trim(query)

    # Navigate to homepage with search query
    if trimmed_query != "" do
      {:noreply, push_navigate(socket, to: ~p"/?q=#{trimmed_query}")}
    else
      {:noreply, push_navigate(socket, to: ~p"/")}
    end
  end
end
