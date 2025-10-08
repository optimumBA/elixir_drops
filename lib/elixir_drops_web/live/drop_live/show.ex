defmodule ElixirDropsWeb.DropLive.Show do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Comments
  alias ElixirDrops.Drops
  alias ElixirDrops.StructuredData
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.CommentComponents

  @consecutive_whitespace_regex ~r/\s+/
  @images_regex ~r/!\[([^\]]*)\]\([^\)]+\)/
  @links_regex ~r/\[([^\]]+)\]\(([^\)]+)\)/

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    user = ElixirDrops.Accounts.get_user!("6c2da68f-5200-43f5-9fb7-24b9b5408fc9")

    {:ok,
     socket
     |> assign(:current_user, user)
     |> stream(:comments, [])}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"short_id" => short_id}, _url, socket) do
    drop = Drops.get_drop_by_short_id(short_id)

    {:noreply,
     socket
     |> assign(:character_count, 0)
     |> assign(:reply_character_count, 0)
     |> assign(:show_user_drops?, false)
     |> assign_drop(drop)}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "new_comment",
        %{"comment" => comment_params, "parent_id" => parent_id},
        socket
      ) do
    comment = create_comment(socket, comment_params, parent_id)

    case comment do
      {:ok, _comment} ->
        changeset = Comments.change_comment(%Comments.Comment{})

        {:noreply,
         socket
         |> assign(:comment_form, to_form(changeset))
         |> assign(:reply_form, to_form(changeset))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:comment_form, to_form(changeset))
         |> assign(:reply_form, to_form(changeset))}
    end
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

  def handle_event("validate_comment", %{"comment" => %{"body" => body} = comment_params}, socket) do
    character_count = String.length(body)

    changeset =
      %Comments.Comment{}
      |> Comments.change_comment(comment_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:comment_form, to_form(changeset))
     |> assign(:character_count, character_count)}
  end

  def handle_event("validate_reply", %{"comment" => %{"body" => body} = comment_params}, socket) do
    character_count = String.length(body)

    changeset =
      %Comments.Comment{}
      |> Comments.change_comment(comment_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:reply_form, to_form(changeset))
     |> assign(:reply_character_count, character_count)}
  end

  def handle_event("cancel", _params, socket) do
    changeset =
      %Comments.Comment{}
      |> Comments.change_comment(%{"body" => ""})

    {:noreply,
     socket
     |> assign(:comment_form, to_form(changeset))
     |> assign(:character_count, 0)
     |> push_event("cancel_comment", %{})}
  end

  def handle_event("cancel_reply", _params, socket) do
    changeset =
      %Comments.Comment{}
      |> Comments.change_comment(%{"body" => ""})

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

    if connected?(socket) do
      Comments.subscribe_to_drop_comments(drop.id)
    end

    comment_changeset = Comments.change_comment(%Comments.Comment{})

    socket
    |> assign(:drop, drop)
    |> assign(:comment_form, to_form(comment_changeset))
    |> assign(:reply_form, to_form(comment_changeset))
    |> assign(:comment_count, drop.comment_count || 0)
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

    socket
    |> stream(:comments, comments, reset: true)
    |> assign(:comment_count, comment_count)
    |> assign(:has_more_comments, comment_count >= 10)
    |> assign(:loaded_comments_count, length(comments))
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
