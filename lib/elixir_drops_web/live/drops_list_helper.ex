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
    <div>
      <div
        id={@id}
        phx-update="stream"
        phx-page-loading
        class={[
          "grid gap-y-2 md:gap-y-5 py-8"
        ]}
      >
        <div
          :if={@show_user_drops?}
          id="drops-empty"
          class="drops-empty only:grid hidden text-[#656565] text-lg min-h-[60svh] items-center justify-center"
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
          class="last:mb-6 cursor-pointer relative"
          role="link"
        >
          <DropComponents.drop_card
            drop={drop}
            show_card_menu?={@show_user_drops?}
            user_id={if @current_user, do: @current_user.id, else: nil}
          />
        </div>

        <div
          :if={drop.screenshot_status == "pending"}
          class="absolute inset-0 bg-black/40 backdrop-blur-sm rounded-lg flex items-center justify-center z-10"
        >
          <DropComponents.loading_spinner />
        </div>
      </div>
      <div id="infinite-scroll-marker" phx-hook="InfiniteScroll" data-page={@page}></div>
    </div>
    """
  end

  @spec assign_drops(socket()) :: socket()
  def assign_drops(socket) do
    drops = Drops.list_drops(socket.assigns.drop_filters)

    last_drop = List.last(drops)

    socket
    |> Phoenix.LiveView.stream(:drops, drops, reset: true, limit: 10)
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

    last_drop = List.last(drops)

    socket
    |> Phoenix.LiveView.stream(:drops, drops, opts)
    |> assign(:last_drop, last_drop)
  end

  @spec load_more(socket()) :: {:noreply, socket()}
  def load_more(%{assigns: %{end_of_timeline?: true}} = socket),
    do: {:noreply, socket}

  def load_more(socket) do
    socket = assign(socket, :page, socket.assigns.page + 1)
    filters = %{older_than: socket.assigns.last_drop}
    {:noreply, maybe_insert_drops(socket, filters, socket.assigns.last_drop)}
  end
end
