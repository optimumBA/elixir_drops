defmodule ElixirDropsWeb.DropLive.Show do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Bookmarks
  alias ElixirDrops.Drops
  alias ElixirDrops.StructuredData
  alias ElixirDropsWeb.DropComponents

  @consecutive_whitespace_regex ~r/\s+/
  @images_regex ~r/!\[([^\]]*)\]\([^\)]+\)/
  @links_regex ~r/\[([^\]]+)\]\(([^\)]+)\)/

  @impl Phoenix.LiveView
  def handle_params(%{"short_id" => short_id}, _url, socket) do
    drop = Drops.get_drop_by_short_id(short_id)

    {:noreply,
     socket
     |> assign(:show_user_drops?, false)
     |> assign_drop(drop)}
  end

  defp assign_drop(socket, nil) do
    socket
    |> assign(:drop, nil)
    |> push_patch(to: ~p"/")
  end

  defp assign_drop(%{assigns: %{current_user: user}} = socket, drop) do
    title =
      drop.title
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()

    socket =
      if user,
        do: assign(socket, :bookmarked?, Bookmarks.drop_bookmarked?(drop.id, user.id)),
        else: assign(socket, :bookmarked?, false)

    socket
    |> assign(:drop, drop)
    |> assign(:page_title, title)
    |> assign_seo_attributes()
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

  def handle_event("remove_from_bookmark", %{"drop_id" => drop_id, "user_id" => user_id}, socket) do
    bookmark = Bookmarks.get_bookmark(drop_id, user_id)

    case Bookmarks.delete_bookmark(bookmark) do
      {:ok, _bookmark} ->
        {:noreply, assign(socket, :bookmarked?, false)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_event("bookmark_drop", %{"drop_id" => drop_id, "user_id" => user_id}, socket) do
    case Bookmarks.create_bookmark(drop_id, user_id) do
      {:ok, _bookmark} ->
        {:noreply, assign(socket, :bookmarked?, true)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end
end
