defmodule ElixirDropsWeb.DropLive.Show do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Comments
  alias ElixirDrops.Comments.CommentsBroadcast
  alias ElixirDrops.Drops
  alias ElixirDrops.StructuredData
  alias ElixirDropsWeb.CommentComponents
  alias ElixirDropsWeb.DropComponents

  @consecutive_whitespace_regex ~r/\s+/
  @images_regex ~r/!\[([^\]]*)\]\([^\)]+\)/
  @links_regex ~r/\[([^\]]+)\]\(([^\)]+)\)/

  # @impl Phoenix.LiveView
  # def mount(_params, _session, socket) do
  #   user = ElixirDrops.Accounts.get_user!("6c2da68f-5200-43f5-9fb7-24b9b5408fc9")

  #   {:ok,
  #    socket
  #    |> assign(:current_user, user)}
  # end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    short_id = params["short_id"]
    drop = Drops.get_drop_by_short_id(short_id)

    if connected?(socket), do: Comments.subscribe(drop.id)

    {:noreply,
     socket
     |> assign(:delete_comment_id, params["delete_comment_id"])
     |> assign(:new_comments?, false)
     |> assign(:recent_comment_id, nil)
     |> assign(:show_user_drops?, false)
     |> assign_drop(drop)}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "new_comment",
        %{"comment" => comment_params, "parent_id" => parent_id, "comment_type" => comment_type},
        socket
      ) do
    parent_id = if parent_id == "nil", do: nil, else: parent_id

    {socket, changeset} =
      case create_comment(socket, comment_params, parent_id) do
        {:ok, comment} ->
          changeset = Comments.change_comment(%Comments.Comment{})
          comments = Comments.list_drop_comments(socket.assigns.drop.id)
          comment_count = socket.assigns.comment_count + 1

          socket =
            socket
            |> assign(:comment_count, comment_count)
            |> assign(:recent_comment_id, comment.id)
            |> stream(:comments, comments, reset: true)

          {socket, changeset}

        {:error, changeset} ->
          {put_flash(socket, :error, "Failed to add your comment"), changeset}
      end

    form_key = if comment_type == "comment", do: :comment_form, else: :reply_form

    {:noreply, assign(socket, form_key, to_form(changeset))}
  end

  def handle_event("edit_comment", %{"comment_id" => comment_id}, socket) do
    changeset =
      comment_id
      |> Comments.get_comment!()
      |> Comments.change_comment()

    {:noreply,
     socket
     |> assign(:comment_form, to_form(changeset))
     |> assign(:editing_comment, comment_id)
     |> push_event("edit_comment", %{comment_id: comment_id})}
  end

  def handle_event(
        "validate_comment",
        %{"comment" => %{"body" => body} = comment_params, "form_id" => form_id},
        socket
      ) do
    character_count = String.length(body)

    changeset =
      %Comments.Comment{}
      |> Comments.change_comment(comment_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:comment_form, to_form(changeset))
     |> push_event("reply_char_count", %{form_id: form_id, count: character_count})}
  end

  def handle_event(
        "validate_reply",
        %{
          "comment" => %{"body" => body} = comment_params,
          "form_id" => form_id,
          "parent_id" => parent_id
        },
        socket
      ) do
    character_count = String.length(body)

    changeset =
      %Comments.Comment{}
      |> Comments.change_comment(comment_params)
      |> Map.put(:action, :validate)

    {
      :noreply,
      socket
      |> assign(:reply_form, to_form(changeset))
      |> push_event("reply_char_count", %{form_id: form_id, count: character_count})
      |> stream_insert(:comments, Comments.get_comment!(parent_id))
    }
  end

  def handle_event("cancel", _params, socket) do
    changeset =
      Comments.change_comment(
        %Comments.Comment{},
        %{"body" => ""}
      )

    {:noreply,
     socket
     |> assign(:comment_form, to_form(changeset))
     |> assign(:character_count, 0)
     |> push_event("cancel_comment", %{})}
  end

  def handle_event("cancel_reply", _params, socket) do
    changeset =
      Comments.change_comment(
        %Comments.Comment{},
        %{"body" => ""}
      )

    {:noreply,
     socket
     |> assign(:reply_form, to_form(changeset))
     |> assign(:reply_character_count, 0)
     |> push_event("cancel_comment", %{})}
  end

  def handle_event("navbar_search_submit", %{"query" => query}, socket) do
    trimmed_query = String.trim(query)

    # Navigate to homepage with search query
    if trimmed_query != "" do
      {:noreply, push_navigate(socket, to: ~p"/?q=#{trimmed_query}")}
    else
      {:noreply, push_navigate(socket, to: ~p"/")}
    end
  end

  def handle_event(
        "delete_comment",
        %{"comment_id" => comment_id, "patch_url" => patch_url},
        socket
      ) do
    comment = Comments.get_comment!(comment_id)

    case Comments.delete_comment(comment) do
      {:ok, _comment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Comment successfully deleted")
         |> push_patch(to: patch_url)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Comment was not deleted")
         |> push_patch(to: patch_url)}
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
        "stream_new_comments",
        _params,
        %{
          assigns: %{
            drop: drop
          }
        } =
          socket
      ) do
    comments = Comments.list_drop_comments(drop.id)

    {:noreply,
     socket
     |> assign(:new_comments?, false)
     |> stream(:comments, comments, reset: true)}
  end

  @impl Phoenix.LiveView
  def handle_info(
        {CommentsBroadcast, :comment_created, comment},
        %{assigns: %{recent_comment_id: recent_comment_id}} = socket
      ) do
    if comment.id == recent_comment_id do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :new_comments?, true)}
    end
  end

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

    comment_changeset = Comments.change_comment(%Comments.Comment{})

    socket
    |> assign(:drop, drop)
    |> assign(:comment_form, to_form(comment_changeset))
    |> assign(:reply_form, to_form(comment_changeset))
    |> assign(:has_more_comments, false)
    |> assign(:replying_to, nil)
    |> assign(:editing_comment, nil)
    |> assign(:page_title, title)
    |> assign_comments(drop)
    |> assign_seo_attributes()
  end

  defp assign_comments(socket, drop) do
    comments = Comments.list_drop_comments(drop.id)

    comment_count = Comments.count_drop_comments(drop.id)
    top_level_comment_count = Comments.count_drop_top_level_comments(drop.id)

    socket
    |> stream(:comments, comments, reset: true)
    |> assign(:comment_offset, 10)
    |> assign(:comment_count, comment_count)
    |> assign(:top_level_comment_count, top_level_comment_count)
  end

  # defp reload_comments_preserving_ui_state(socket) do
  #   %{drop: drop} = socket.assigns
  #   comments = Comments.list_drop_comments(drop.id)
  #   comment_count = Comments.count_drop_comments(drop.id)

  #   socket
  #   |> stream(:comments, comments, reset: true)
  #   |> assign(:comment_count, comment_count)
  #   |> assign(:has_more_comments, length(comments) >= 10)
  # end

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
