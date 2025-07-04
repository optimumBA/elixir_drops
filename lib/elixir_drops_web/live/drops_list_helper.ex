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
    assigns =
      assigns
      |> Map.put_new(:loading_more, false)
      |> Map.put_new(:batch_size, 10)
      |> Map.put_new(:search_query, "")
      |> Map.put_new(:searching, false)

    ~H"""
    <div class="mt-12">
      <div class={[@drops_empty? && "py-8", !@drops_empty? && "masonry-container py-8"]}>
        <div
          id={@id}
          phx-update="stream"
          phx-page-loading
          phx-hook={!@drops_empty? && "Masonry"}
          class={[
            @drops_empty? && "grid gap-y-2 md:gap-y-5 px-6 md:px-8 lg:px-12",
            !@drops_empty? && "masonry-grid"
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
            :if={@searching && @drops_empty?}
            id="search-empty"
            class="drops-empty only:grid hidden text-[#656565] text-lg min-h-[60svh] items-center justify-center"
          >
            <div class="flex flex-col items-center justify-center">
              <.icon name="hero-magnifying-glass" class="w-16 h-16 text-gray-400 mb-4" />
              <p class="text-xl font-semibold text-gray-700 mb-2">No drops found</p>
              <p class="text-gray-500 mb-4">No drops match your search for "<%= @search_query %>"</p>
              <button phx-click="clear_search" class="text-blue-600 hover:text-blue-800 font-medium">
                Clear search
              </button>
            </div>
          </div>
          <div
            :for={{dom_id, drop} <- @drops}
            id={dom_id}
            phx-click={JS.navigate(~p"/d/#{drop.short_id}")}
            class="masonry-item cursor-pointer relative"
            role="link"
          >
            <div class="relative">
              <DropComponents.drop_card
                drop={drop}
                show_card_menu?={@show_user_drops?}
                user_id={@current_user && @current_user.id}
              />

              <div
                :if={drop.screenshot && drop.screenshot.status == :pending}
                class="absolute inset-0 bg-black/40 backdrop-blur-sm rounded-lg flex items-center justify-center z-10"
              >
                <DropComponents.loading_spinner id="loading-spinner" />
              </div>
            </div>
          </div>
        </div>
      </div>

      <div
        data-end-of-timeline={if assigns[:end_of_timeline?], do: "true", else: "false"}
        data-page={@page}
        id="infinite-scroll-marker"
        phx-hook="InfiniteScroll"
      >
      </div>

      <div :if={@loading_more && !assigns[:end_of_timeline?]} class="masonry-loading-indicator">
        <div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
        <span>Loading <%= @batch_size %> more...</span>
      </div>
    </div>
    """
  end

  @spec assign_drops(socket()) :: socket()
  def assign_drops(socket) do
    batch_size = Map.get(socket.assigns, :batch_size, 15)
    drops = Drops.list_drops(socket.assigns.drop_filters, batch_size)

    last_drop = List.last(drops)

    socket
    |> Phoenix.LiveView.stream(:drops, drops, reset: true, limit: batch_size)
    |> assign(:drops_empty?, Enum.empty?(drops))
    |> assign(:end_of_timeline?, false)
    |> assign(:last_drop, last_drop)
    |> assign(:loading_more, false)
  end

  @spec maybe_insert_drops(socket(), filters(), drop(), opts()) :: socket()
  def maybe_insert_drops(socket, _filters, _first_or_last_drop, _opts \\ [])

  def maybe_insert_drops(socket, _filters, nil, _opts) do
    assign(socket, :end_of_timeline?, true)
  end

  def maybe_insert_drops(socket, filters, _first_or_last_drop, opts) do
    batch_size = Map.get(socket.assigns, :batch_size, 15)

    drops =
      filters
      |> Map.merge(socket.assigns.drop_filters)
      |> Drops.list_drops(batch_size)

    last_drop = List.last(drops)

    socket
    |> Phoenix.LiveView.stream(:drops, drops, opts)
    |> assign(:end_of_timeline?, Enum.count(drops) < batch_size)
    |> assign(:last_drop, last_drop)
  end

  @spec load_more(socket(), pos_integer()) :: {:noreply, socket()}
  def load_more(socket, batch_size \\ 10)

  def load_more(%{assigns: %{end_of_timeline?: true}} = socket, _batch_size),
    do: {:noreply, socket}

  def load_more(socket, _batch_size) do
    filters = %{older_than: socket.assigns.last_drop}

    socket =
      socket
      |> assign(:loading_more, false)
      |> assign(:page, socket.assigns.page + 1)
      |> maybe_insert_drops(filters, socket.assigns.last_drop)
      |> Phoenix.LiveView.push_event("load-more-complete", %{})

    {:noreply, socket}
  end
end
