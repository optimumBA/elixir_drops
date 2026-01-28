defmodule ElixirDropsWeb.UserDropLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Notifications
  alias ElixirDropsWeb.BookmarkHelpers
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropsListHelper
  alias ElixirDropsWeb.LiveHelpers
  alias ElixirDropsWeb.SearchHelper
  alias ElixirDropsWeb.UserDropLive.Bookmarks
  alias ElixirDropsWeb.UserDropLive.FormComponent

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    if connected?(socket) do
      Drops.subscribe()
      Notifications.subscribe(user_id)
    end

    {:ok,
     socket
     |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
     |> assign(:batch_size, 15)
     |> assign(:bookmark_search_query, "")
     |> assign(:bookmark_tab?, false)
     |> assign(:drop_filters, %{user_id: user_id, bookmarks_user_id: user_id})
     |> assign(:drops_empty?, true)
     |> assign(:end_of_notifications_timeline?, false)
     |> assign(:end_of_timeline?, false)
     |> assign(:loading_more, false)
     |> assign(:page, 1)
     |> assign(:search_query, "")
     |> assign(:viewport_height, nil)
     |> assign(:viewport_width, nil)
     |> SearchHelper.initialize_profile_search_assigns(user_id)}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, %{assigns: %{live_action: live_action}} = socket) do
    search_query = params["q"] || ""

    if live_action == :show_bookmarks do
      {:noreply,
       socket
       |> assign(:bookmark_search_query, search_query)
       |> assign(:bookmark_tab?, true)}
    else
      {:noreply,
       socket
       |> assign(:search_query, search_query)
       |> assign(:searching, search_query != "")
       |> SearchHelper.update_search_filters(search_query)
       |> DropsListHelper.assign_drops()
       |> apply_action(live_action, params)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("update_viewport", %{"width" => width, "height" => height}, socket),
    do: {:noreply, LiveHelpers.update_viewport(width, height, socket)}

  def handle_event("search_submit", %{"query" => query}, socket) do
    trimmed_query =
      query
      |> to_string()
      |> String.trim()

    # Track search history and popular searches
    SearchHelper.track_search(query, socket, %{})

    socket =
      socket
      |> assign(:search_suggestions, [])
      |> assign(:search_query, trimmed_query)
      |> assign(:show_profile_suggestions?, false)

    # Stay on profile page with search query
    if trimmed_query != "" do
      {:noreply, push_navigate(socket, to: ~p"/profile?q=#{trimmed_query}")}
    else
      {:noreply, push_navigate(socket, to: ~p"/profile")}
    end
  end

  def handle_event("close_search_overlay", _params, socket) do
    {:noreply, assign(socket, :show_profile_suggestions?, false)}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_suggestions, [])
     |> assign(:search_query, "")
     |> assign(:show_profile_suggestions?, false)
     |> push_patch(to: ~p"/profile")}
  end

  def handle_event("load_suggestions", %{"query" => query}, socket) when is_binary(query) do
    user_id = socket.assigns.current_user.id
    suggestions = ElixirDrops.Search.get_search_suggestions(user_id, query)

    {:noreply,
     socket
     |> assign(:search_suggestions, suggestions)
     |> assign(:show_profile_suggestions?, length(suggestions) > 0)}
  end

  def handle_event("load_suggestions", _params, socket) do
    {:noreply, assign(socket, :show_profile_suggestions?, false)}
  end

  def handle_event("blur_search_input", _params, socket) do
    {:noreply, assign(socket, :show_profile_suggestions?, false)}
  end

  def handle_event("focus_search_input", _params, socket) do
    user_id = socket.assigns.current_user.id
    {suggestions, show_suggestions?} = SearchHelper.get_focus_search_suggestions(user_id)

    {:noreply,
     socket
     |> assign(:search_suggestions, suggestions)
     |> assign(:show_profile_suggestions?, show_suggestions?)}
  end

  # Handle navbar search submit - navigate to homepage with search
  def handle_event("navbar_search_submit", %{"query" => query}, socket) do
    trimmed_query = String.trim(query)
    # Track search history and popular searches
    SearchHelper.track_search(query, socket, %{})

    socket =
      socket
      |> assign(:navbar_search_query, trimmed_query)
      |> assign(:show_suggestions?, false)

    # Navigate to homepage with search query
    if trimmed_query != "" do
      {:noreply, push_navigate(socket, to: ~p"/?q=#{trimmed_query}")}
    else
      {:noreply, push_navigate(socket, to: ~p"/")}
    end
  end

  def handle_event(event, params, socket)
      when event in ["remove_from_bookmark", "bookmark_drop"],
      do: BookmarkHelpers.handle_bookmark_event(event, params, socket)

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp apply_action(socket, :edit, %{"short_id" => short_id}) do
    filters = %{
      short_id: short_id,
      user_id: socket.assigns.current_user.id
    }

    assign_user_drop(socket, filters)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:drop, %Drop{})
    |> assign(:page_title, "Create Drop")
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:drop, nil)
    |> assign(:page_title, "ElixirDrops | #{socket.assigns.current_user.github_username}")
  end

  defp assign_user_drop(socket, filters) do
    case Drops.get_drop(filters) do
      nil ->
        socket
        |> assign(:drop, nil)
        |> put_flash(:error, "You can only edit your own drops")
        |> push_navigate(to: ~p"/")

      %Drop{} = drop ->
        socket
        |> assign(:drop, drop)
        |> assign(:page_title, "Edit Drop")
    end
  end

  @impl Phoenix.LiveView
  def handle_info({Drops, [:drop, :created], _drop}, socket) do
    {:noreply,
     socket
     |> assign(:page, 1)
     |> DropsListHelper.assign_drops()}
  end

  def handle_info(
        {Drops, [:drop, :screenshot_generation_started], drop},
        %{assigns: %{live_action: action}} = socket
      )
      when action in [:edit, :new] do
    screenshot = %{
      drop_short_id: drop.short_id,
      progress_value: 0,
      status: :pending,
      url: nil
    }

    send_update(FormComponent, id: "drops-form", screenshot: screenshot)

    {:noreply, push_event(socket, "screenshot_generation_started", %{})}
  end

  def handle_info(
        {Drops, [:drop, :screenshot_generation_completion], drop, progress, status, _metadata},
        %{assigns: %{live_action: action}} = socket
      )
      when action in [:edit, :new] do
    screenshot = %{
      drop_short_id: drop.short_id,
      progress_value: progress,
      status: status,
      url: drop.screenshot.internal_url
    }

    send_update(FormComponent,
      id: "drops-form",
      screenshot: screenshot
    )

    {:noreply, socket}
  end

  def handle_info({Drops, [:drop, :screenshot_generation_started], _drop}, socket) do
    {:noreply, DropsListHelper.assign_drops(socket)}
  end

  def handle_info(
        {Drops, [:drop, :screenshot_generation_completion], drop, _progress, status, _metadata},
        socket
      ) do
    if status == :completed do
      {:noreply, stream_insert(socket, :drops, drop)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:update_search_query, query}, socket),
    do: {:noreply, assign(socket, :search_query, query)}

  def handle_info(_message, socket) do
    {:noreply, socket}
  end
end
