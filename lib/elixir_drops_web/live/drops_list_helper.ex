defmodule ElixirDropsWeb.DropsListHelper do
  @moduledoc false

  use ElixirDropsWeb, :html

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDropsWeb.DropComponents

  @type assigns :: map()
  @type drop :: Drop.t()
  @type filters :: map()
  @type opts :: Keyword.t()
  @type rendered :: Phoenix.LiveView.Rendered.t()
  @type socket :: Phoenix.LiveView.Socket.t()

  @spec drops_list(assigns()) :: rendered()
  def drops_list(assigns) do
    ~H"""
    <div
      id={@id}
      phx-update="stream"
      phx-viewport-top={!@end_of_timeline? && JS.push("prev-page")}
      phx-viewport-bottom={!@end_of_timeline? && JS.push("next-page")}
      phx-page-loading
      class={[
        "grid grid-cols-1 md:grid-cols-3 gap-4 md:gap-5 py-8 auto-rows-auto px-12"
      ]}
    >
      <div
        :if={@show_user_drops?}
        id="drops-empty"
        class="drops-empty only:grid hidden text-[#656565] text-lg min-h-[60svh] items-center justify-center md:col-span-3"
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
        :for={{dom_id, drop} <- @drops}
        id={dom_id}
        phx-click={JS.navigate(~p"/d/#{drop.short_id}")}
        class="last:mb-6 cursor-pointer self-start"
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

  @spec assign_drops(socket()) :: socket()
  def assign_drops(socket) do
    drops = Drops.list_drops(socket.assigns.drop_filters)

    first_drop = List.first(drops)
    last_drop = List.last(drops)

    socket
    |> Phoenix.LiveView.stream(:drops, drops, reset: true, limit: 10)
    |> assign(:first_drop, first_drop)
    |> assign(:last_drop, last_drop)
  end

  @spec maybe_insert_drops(socket(), filters(), drop(), opts()) :: socket()
  def maybe_insert_drops(socket, _filters, _first_or_last_drop, _opts \\ [])

  def maybe_insert_drops(socket, _filters, nil, _opts) do
    assign(socket, :end_of_timeline?, true)
  end

  def maybe_insert_drops(socket, filters, _first_or_last_drop, opts) do
    drops =
      filters
      |> Map.merge(socket.assigns.drop_filters)
      |> Drops.list_drops()

    first_drop = List.first(drops)
    last_drop = List.last(drops)

    socket
    |> Phoenix.LiveView.stream(:drops, drops, opts)
    |> assign(:first_drop, first_drop)
    |> assign(:last_drop, last_drop)
  end
end
