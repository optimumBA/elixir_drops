defmodule ElixirDropsWeb.DropsListComponent do
  @moduledoc false

  use ElixirDropsWeb, :live_component

  alias ElixirDrops.Drops
  alias ElixirDropsWeb.DropComponents

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      phx-update="stream"
      phx-viewport-top={!@end_of_timeline? && JS.push("prev-page", target: @myself)}
      phx-viewport-bottom={!@end_of_timeline? && JS.push("next-page", target: @myself)}
      phx-page-loading
      class={[
        "grid gap-y-2 md:gap-y-5 py-8"
      ]}
    >
      <div
        :if={@show_user_drops?}
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

      <div
        :for={{dom_id, drop} <- @streams.drops}
        id={dom_id}
        phx-click={JS.navigate(~p"/drops/#{drop.id}")}
        class="last:mb-6 cursor-pointer"
        role="link"
      >
        <DropComponents.drop_card
          drop={drop}
          show_card_menu?={@show_user_drops?}
          timezone_offset={@timezone_offset}
        />
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, stream_configure(socket, :drops, dom_id: &"drop-#{&1.id}")}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:end_of_timeline?, false)
     |> assign_drops()}
  end

  @impl Phoenix.LiveComponent
  def handle_event("next-page", _params, socket) do
    filters = %{older_than: socket.assigns.last_drop}

    {
      :noreply,
      maybe_insert_drops(socket, filters, socket.assigns.last_drop)
    }
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, socket}
  end

  def handle_event("prev-page", _params, socket) do
    filters = %{newer_than: socket.assigns.first_drop}

    {
      :noreply,
      maybe_insert_drops(socket, filters, socket.assigns.first_drop, at: 0)
    }
  end

  def handle_event("refresh-drops", _params, socket) do
    send(self(), {:refreshed_drops?, true})

    {:noreply, assign_drops(socket)}
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

  defp maybe_insert_drops(socket, _filters, _first_or_last_drop, _opts \\ [])

  defp maybe_insert_drops(socket, _filters, nil, _opts) do
    assign(socket, :end_of_timeline?, true)
  end

  defp maybe_insert_drops(socket, filters, _first_or_last_drop, opts) do
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

  defp stream_insert_many(socket, stream_key, items, opts) do
    Enum.reduce(items, socket, fn item, socket ->
      stream_insert(socket, stream_key, item, opts)
    end)
  end
end
