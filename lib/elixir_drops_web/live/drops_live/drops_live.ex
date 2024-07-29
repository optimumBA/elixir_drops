defmodule ElixirDropsWeb.DropsLive do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDropsWeb.DropsComponents

  @drops_per_page 10
  @initial_page 1

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:page, @initial_page)
      |> assign(:per_page, @drops_per_page)
      |> assign(:show_user_drops?, false)
      |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
    }
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl Phoenix.LiveView
  def handle_event("next-page", _params, socket) do
    {:noreply, assign_drops(socket, socket.assigns.page + 1)}
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, assign_drops(socket, 1)}
  end

  def handle_event("prev-page", _params, socket) do
    if socket.assigns.page > 1 do
      {:noreply, assign_drops(socket, socket.assigns.page - 1)}
    else
      {:noreply, socket}
    end
  end

  defp apply_action(socket, :index, %{"user_name" => _user_name}) do
    user_id = socket.assigns.current_user.id

    socket
    |> assign(:drop, nil)
    |> assign(:page_title, "ElixirDrops")
    |> assign(:show_user_drops?, true)
    |> assign_drops(1, [reset: true], %{user_id: user_id})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:drop, nil)
    |> assign(:page_title, "ElixirDrops")
    |> assign_drops(1, reset: true)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    id
    |> Drops.get_drop()
    |> assign_drop(socket)
  end

  defp assign_drop(nil, socket) do
    socket
    |> assign(:drop, nil)
    |> push_patch(to: ~p"/")
  end

  defp assign_drop(drop, socket) do
    socket
    |> assign(:drop, drop)
    |> assign(:page_title, drop.title)
  end

  defp assign_drops(socket, new_page, opts \\ [], filters \\ %{}) when new_page >= 1 do
    %{page: page, per_page: per_page} = socket.assigns

    per_page
    |> Drops.list_drops(filters, page)
    |> stream_drops(new_page, socket, opts)
  end

  defp stream_drops(%{entries: []}, _new_page, socket, _opts) do
    socket
    |> assign(:end_of_timeline?, true)
    |> stream(:drops, [])
  end

  defp stream_drops(drops_list, new_page, socket, opts) do
    drops_list
    |> process_entries(new_page, socket)
    |> assign_drops_stream(new_page, socket, opts)
  end

  defp process_entries(%{current_page: current_page} = drops_list, new_page, socket)
       when new_page >= current_page do
    %{
      at: -1,
      current_page: current_page,
      entries: drops_list.entries,
      limit: socket.assigns.per_page * 3 * -1,
      total_pages: drops_list.total_pages
    }
  end

  defp process_entries(drops_list, new_page, socket) do
    %{
      at: 0,
      current_page: new_page,
      entries: Enum.reverse(drops_list.entries),
      limit: socket.assigns.per_page * 3,
      total_pages: drops_list.total_pages
    }
  end

  defp assign_drops_stream(%{entries: [], at: at}, _new_page, socket, _opts) do
    assign(socket, :end_of_timeline?, at == -1)
  end

  defp assign_drops_stream(drops_list, new_page, socket, opts) do
    %{at: at, current_page: current_page, entries: entries, total_pages: total_pages} = drops_list

    reset = opts[:reset] || false

    socket
    |> assign(:end_of_timeline?, current_page == total_pages)
    |> assign(:page, new_page)
    |> stream(:drops, entries, at: at, reset: reset)
  end
end
