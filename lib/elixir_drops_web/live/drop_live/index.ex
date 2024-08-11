defmodule ElixirDropsWeb.DropLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDropsWeb.DropLive.DropComponents
  alias ElixirDropsWeb.DropLive.FormComponent

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Drops.subscribe()

    {
      :ok,
      socket
      |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
      |> assign(:end_of_timeline?, false)
      |> assign(:new_drops?, false)
      |> assign(:show_user_drops?, false)
    }
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl Phoenix.LiveView
  def handle_info({Drops, [:drop, :created], _drop}, socket) do
    {:noreply, assign(socket, :new_drops?, true)}
  end

  @impl Phoenix.LiveView
  def handle_event("next-page", _params, socket) do
    socket = insert_drops(socket, %{older_than: socket.assigns.last_drop})

    {
      :noreply,
      assign(socket, :end_of_timeline?, is_nil(socket.assigns.last_drop))
    }
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, socket}
  end

  def handle_event("prev-page", _params, socket) do
    socket = insert_drops(socket, %{newer_than: socket.assigns.first_drop}, at: 0)

    {
      :noreply,
      assign(socket, :end_of_timeline?, is_nil(socket.assigns.first_drop))
    }
  end

  def handle_event("refresh-drops", _params, socket) do
    {:noreply, assign_drops(socket)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Drops.get_drop(id) do
      nil ->
        socket
        |> assign(:drop, nil)
        |> push_navigate(to: ~p"/")

      %Drop{} = drop ->
        socket
        |> assign(:drop, drop)
        |> assign(:page_title, "Edit Drop")
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:drop, %Drop{})
    |> assign(:page_title, "Create Drop")
  end

  defp apply_action(socket, :index, %{"user_name" => user_name}) do
    user_id = socket.assigns.current_user.id

    socket
    |> assign(:drop, nil)
    |> assign(:page_title, "ElixirDrops | #{user_name}")
    |> assign(:show_user_drops?, true)
    |> assign_drops(%{user_id: user_id})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:drop, nil)
    |> assign(:page_title, "ElixirDrops")
    |> assign(:show_user_drops?, false)
    |> assign_drops()
  end

  defp assign_drops(socket, filters \\ %{}) do
    drops = Drops.list_drops(filters)
    first_drop = List.first(drops)
    last_drop = List.last(drops)

    socket
    |> stream(:drops, drops, reset: true)
    |> assign(:first_drop, first_drop)
    |> assign(:last_drop, last_drop)
  end

  defp insert_drops(socket, filters, opts \\ []) do
    drops =
      socket
      |> maybe_filter_user_drops(filters)
      |> Drops.list_drops()

    first_drop = List.first(drops)
    last_drop = List.last(drops)

    socket
    |> stream_insert_many(:drops, drops, opts)
    |> assign(:first_drop, first_drop)
    |> assign(:last_drop, last_drop)
  end

  defp maybe_filter_user_drops(socket, filters) do
    if socket.assigns.show_user_drops? do
      Map.put(filters, :user_id, socket.assigns.current_user.id)
    else
      filters
    end
  end
end
