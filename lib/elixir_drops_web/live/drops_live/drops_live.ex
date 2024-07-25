defmodule ElixirDropsWeb.DropsLive do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDropsWeb.DropsLive.DropsComponents

  @drops_per_page 10
  @initial_page 1

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:page, @initial_page)
      |> assign(:per_page, @drops_per_page)
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

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:drop, nil)
    |> assign(:page_title, "ElixirDrops")
    |> assign_drops(1)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    case Drops.get_drop(id) do
      nil ->
        socket
        |> put_flash(:error, "Drop not found")
        |> push_patch(to: ~p"/")

      drop ->
        socket
        |> assign(:drop, drop)
        |> assign(:page_title, drop.title)
    end
  end

  def assign_drops(socket, new_page, filters \\ %{}) when new_page >= 1 do
    %{page: page, per_page: per_page} = socket.assigns

    per_page
    |> Drops.list_drops(filters, page)
    |> process_entries(new_page, socket)
    |> stream_drops(new_page, socket)
  end

  defp process_entries(drop_list_result, new_page, socket) do
    %{current_page: current_page, entries: entries, total_pages: total_pages} = drop_list_result

    if new_page >= current_page do
      %{
        at: -1,
        current_page: current_page,
        entries: entries,
        limit: socket.assigns.per_page * 3 * -1,
        total_pages: total_pages
      }
    else
      %{
        at: 0,
        current_page: current_page,
        entries: Enum.reverse(entries),
        limit: socket.assigns.per_page * 3,
        total_pages: total_pages
      }
    end
  end

  defp stream_drops(%{entries: entries, at: at}, _new_page, socket) when length(entries) == 0 do
    assign(socket, :end_of_timeline?, at == -1)
  end

  defp stream_drops(drops_list, new_page, socket) do
    %{at: at, current_page: current_page, entries: entries, total_pages: total_pages} = drops_list

    socket
    |> assign(:end_of_timeline?, current_page == total_pages)
    |> assign(:page, new_page)
    |> stream(:drops, entries, dom_id: &"drop-#{&1.id}", at: at)
  end
end
