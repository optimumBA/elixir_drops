defmodule ElixirDropsWeb.DropsListComponent do
  @moduledoc false

  use ElixirDropsWeb, :live_component

  alias ElixirDrops.Drops
  alias ElixirDropsWeb.DropComponents

  @impl Phoenix.LiveComponent
  def update(%{refresh_drops: true}, socket) do
    {:ok,
     socket
     |> assign_drops()
     |> assign(:end_of_timeline?, false)}
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    {:ok,
     socket
     |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
     |> assign(:end_of_timeline?, false)
     |> assign_drops()}
  end

  @impl Phoenix.LiveComponent
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
    send(self(), :drops_refreshed)

    {:noreply, stream(socket, :drops, [], reset: true)}
  end

  defp assign_drops(socket) do
    drops = Drops.list_drops(socket.assigns.drop_filters)

    first_drop = List.first(drops)
    last_drop = List.last(drops)

    socket
    |> stream(:drops, drops, reset: true)
    |> assign(:first_drop, first_drop)
    |> assign(:last_drop, last_drop)
  end

  defp insert_drops(socket, filters, opts \\ []) do
    drops =
      filters
      |> Map.merge(socket.assigns.drop_filters)
      |> Drops.list_drops()

    first_drop = List.first(drops)
    last_drop = List.last(drops)

    socket
    |> stream_insert_many(:drops, drops, opts)
    |> assign(:first_drop, first_drop)
    |> assign(:last_drop, last_drop)
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div
      id="drops"
      phx-update="stream"
      phx-viewport-top={!@end_of_timeline? && JS.push("prev-page", target: @myself)}
      phx-viewport-bottom={!@end_of_timeline? && JS.push("next-page", target: @myself)}
      phx-page-loading
      class={[
        "grid gap-y-2 md:gap-y-5 py-8"
      ]}
    >
      <div
        :if={@show_card_menu?}
        id="drops-empty"
        class="only:grid hidden text-[#656565] text-lg min-h-[60svh] items-center justify-center"
      >
        <div class="flex flex-col items-center justify-center">
          <p>You haven't created any post yet.</p>
          <.link
            navigate={~p"/drops/new"}
            class="text-[#eae8fd] text-sm bg-blue_primary hover:opacity-80 px-4 md:hidden py-2 mt-2 rounded-lg flex items-center gap-x-2"
          >
            <span><.icon name="hero-plus" class="text-[#eae8fd] h-5 w-5" /></span>
            <span> Create Post</span>
          </.link>
        </div>
      </div>

      <.link
        :for={{dom_id, drop} <- @streams.drops}
        id={dom_id}
        patch={~p"/drops/#{drop.id}"}
        class="last:mb-6"
      >
        <DropComponents.drop_card
          avatar={drop.user.avatar}
          created_at={drop.inserted_at}
          github_username={drop.user.github_username}
          id={drop.id}
          show_card_menu?={@show_card_menu?}
          timezone_offset={@timezone_offset}
          title={drop.title}
        />
      </.link>
    </div>
    """
  end
end
