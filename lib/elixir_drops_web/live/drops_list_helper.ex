defmodule ElixirDropsWeb.DropsListHelper do
  @moduledoc false

  use ElixirDropsWeb, :html

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Search
  alias ElixirDropsWeb.DropComponents

  @type assigns :: map()
  @type drop :: Drop.t()
  @type filters :: map()
  @type opts :: Keyword.t()
  @type rendered :: Phoenix.LiveView.Rendered.t()
  @type socket :: Phoenix.LiveView.Socket.t()

  attr :batch_size, :integer, default: 10
  attr :current_user, :any
  attr :drops, :list, required: true
  attr :drops_empty?, :boolean, required: true
  attr :end_of_timeline?, :boolean
  attr :id, :string, required: true
  attr :loading_more, :boolean, default: false
  attr :page, :integer
  attr :search_query, :string, default: ""
  attr :searching, :boolean, default: false

  @spec drops_list(assigns()) :: rendered()
  def drops_list(assigns) do
    # Check if we're searching and have no results
    is_search_no_results = assigns.searching && assigns.drops_empty?

    assigns =
      assigns
      |> Map.put_new(:loading_more, false)
      |> Map.put_new(:batch_size, 10)
      |> Map.put_new(:search_query, "")
      |> Map.put_new(:searching, false)
      |> assign(:is_search_no_results, is_search_no_results)

    ~H"""
    <div class="mt-12">
      <!-- No search results component -->
      <div :if={@is_search_no_results}>
        <DropComponents.no_results
          search_query={@search_query}
          suggested_searches={get_suggested_searches()}
        />
      </div>
      <!-- Regular drops list -->
      <div
        :if={!@is_search_no_results}
        class={[@drops_empty? && "py-8", !@drops_empty? && "masonry-container py-8"]}
      >
        <div
          id={@id}
          phx-update="stream"
          phx-page-loading
          phx-hook={!@drops_empty? && "Masonry"}
          phx-connected={JS.dispatch("load_masonry", to: "##{@id}")}
          class={[
            @drops_empty? && "grid gap-y-2 md:gap-y-5 px-6 md:px-8 lg:px-12",
            !@drops_empty? && "masonry-grid"
          ]}
        >
          <div
            :if={@drops_empty?}
            id="drops-empty"
            class="only:grid text-[#656565] text-lg min-h-[60svh] items-center justify-center"
          >
            <div class="flex flex-col items-center justify-center">
              <p>You haven't created any drop yet.</p>
              <.link
                navigate={~p"/drops/new"}
                class="text-[#eae8fd] text-sm bg-blue_primary hover:opacity-80 px-4 py-2 mt-2 rounded-lg flex items-center gap-x-2"
              >
                <span><.icon name="hero-plus" class="text-[#eae8fd] h-5 w-5" /></span>
                <span> Create Drop</span>
              </.link>
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
                show_card_menu?={true}
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

          <div
            data-end-of-timeline={if assigns[:end_of_timeline?], do: "true", else: "false"}
            data-page={@page}
            id="infinite-scroll-marker"
            phx-hook="InfiniteScroll"
            class="absolute h-3 w-full bottom-0"
          >
          </div>
        </div>
      </div>
      <div :if={!@is_search_no_results}>
        <div :if={@loading_more && !assigns[:end_of_timeline?]} class="masonry-loading-indicator">
          <div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin">
          </div>
          <span>Loading {@batch_size} more...</span>
        </div>
      </div>
    </div>
    """
  end

  # Helper function to get suggested searches for no results
  defp get_suggested_searches do
    # Get top popular searches from database ordered by search count, fallback to hardcoded list if empty
    popular_searches =
      Search.list_popular_searches()
      |> Enum.sort_by(& &1.search_count, :desc)
      |> Enum.take(5)
      |> Enum.map(& &1.query)

    if Enum.empty?(popular_searches) do
      # Fallback to hardcoded suggestions if no popular searches exist
      ~w[phoenix elixir ecto liveview genserver]
    else
      popular_searches
    end
  end

  @spec assign_drops(socket()) :: socket()
  def assign_drops(socket) do
    batch_size = Map.get(socket.assigns, :batch_size, 15)
    drops = Drops.list_drops(socket.assigns.drop_filters, batch_size)
    socket = assign_drop_cursor(socket.assigns.search_query, drops, socket)

    socket
    |> Phoenix.LiveView.stream(:drops, drops, reset: true, limit: batch_size)
    |> assign(:drops_empty?, Enum.empty?(drops))
    |> assign(:end_of_timeline?, false)
    |> assign(:loading_more, false)
  end

  @spec maybe_insert_drops(socket()) :: socket()
  def maybe_insert_drops(socket) do
    search_query = socket.assigns.search_query
    drop_filters = socket.assigns.drop_filters
    batch_size = Map.get(socket.assigns, :batch_size, 15)
    drops = Drops.list_drops(drop_filters, batch_size)

    filters =
      case Enum.empty?(drops) do
        true ->
          Map.merge(drop_filters, %{
            relevance_rank: {0, search_query}
          })

        false ->
          last_drop = List.last(drops)

          Map.merge(drop_filters, %{
            relevance_rank: {last_drop.relevance_rank, search_query}
          })
      end

    socket
    |> Phoenix.LiveView.stream(:drops, drops)
    |> assign(:drop_filters, filters)
    |> assign(:end_of_timeline?, Enum.count(drops) < batch_size)
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
    socket = assign_drops_with_cursor(socket.assigns.search_query, socket)

    {:noreply, socket}
  end

  defp assign_drops_with_cursor(search_query, socket) when search_query != "" do
    socket
    |> assign(:loading_more, false)
    |> assign(:page, socket.assigns.page + 1)
    |> maybe_insert_drops()
    |> Phoenix.LiveView.push_event("load-more-complete", %{})
  end

  defp assign_drops_with_cursor(_search_query, socket) do
    filters = %{older_than: socket.assigns.last_drop}

    socket
    |> assign(:loading_more, false)
    |> assign(:page, socket.assigns.page + 1)
    |> maybe_insert_drops(filters, socket.assigns.last_drop)
    |> Phoenix.LiveView.push_event("load-more-complete", %{})
  end

  defp assign_drop_cursor(search_query, drops, socket) when search_query != "" and drops != [] do
    last_drop = List.last(drops)

    filters =
      Map.merge(socket.assigns.drop_filters, %{
        relevance_rank: {last_drop.relevance_rank, search_query}
      })

    assign(socket, :drop_filters, filters)
  end

  defp assign_drop_cursor(_search_query, drops, socket) do
    last_drop = List.last(drops)
    assign(socket, :last_drop, last_drop)
  end
end
