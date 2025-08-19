defmodule ElixirDropsWeb.DropComponents do
  @moduledoc false

  use ElixirDropsWeb, :html

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Drops.Drop
  alias ElixirDropsWeb.Icons

  @type assigns :: map()
  @type rendered :: Phoenix.LiveView.Rendered.t()

  attr :current_user, User
  attr :live_action, :atom, required: true
  attr :search_query, :string, default: ""
  attr :show_suggestions, :boolean, default: false
  attr :search_suggestions, :list, default: []
  attr :show_user_drops?, :boolean, default: false

  @spec navbar(assigns()) :: rendered()
  def navbar(assigns) do
    ~H"""
    <header class="header px-10 py-2 w-full relative z-30">
      <nav class="breakout flex items-center justify-between nav-primary">
        <div>
          <.link href={~p"/"}>
            <Icons.elixir_drops_logo class="w-32 md:w-48" />
          </.link>
        </div>
        <!-- Desktop Search -->
        <div class="hidden lg:flex flex-1 max-w-md mx-8">
          <.search_input_desktop
            search_query={@search_query}
            show_suggestions={@show_suggestions}
            search_suggestions={@search_suggestions}
            current_user={@current_user}
          />
        </div>
        <div>
          <div class="flex items-center gap-x-4">
            <!-- Mobile/Tablet Search Icon -->
            <button
              class="lg:hidden p-2 text-[#4F4F4F] hover:text-[#5947F1]"
              phx-click={JS.toggle(to: "#search-overlay")}
            >
              <.icon name="hero-magnifying-glass" class="h-5 w-5" />
            </button>
            <!-- Create Drop Button - Always visible -->
            <.create_drop_button current_user={@current_user} live_action={@live_action} />

            <%= if @current_user do %>
              <div
                class="flex items-center gap-x-3 cursor-pointer"
                phx-click={JS.toggle_class("hidden", to: "#slide-menu")}
              >
                <img
                  src={@current_user.avatar}
                  alt={@current_user.github_username}
                  class="w-10 h-10 rounded-full"
                />
                <p class="hidden md:block">{@current_user.github_username}</p>
                <button class="hidden md:block">
                  <.icon name="hero-chevron-down" class="text-[#4F4F4F]" />
                </button>
                <.slide_menu current_user={@current_user} />
              </div>
            <% else %>
              <.link
                href={~p"/auth/github"}
                class="font-semibold text-[#eae8fd] text-xs md:text-sm bg-blue_primary hover:opacity-80 px-2 md:px-5 py-2 rounded-lg flex items-center gap-x-2"
              >
                <span><Icons.github_icon /></span>
                <span> Sign in with GitHub</span>
              </.link>
            <% end %>
          </div>
        </div>
      </nav>
    </header>
    """
  end

  attr :drop, Drop, required: true
  attr :show_card_menu?, :boolean, default: false
  attr :user_id, :string

  @spec drop_card(assigns()) :: rendered()
  def drop_card(assigns) do
    assigns = assign(assigns, :text, get_preview_text(assigns.drop.body))

    ~H"""
    <div
      class="drop-card"
      id={"drop-card-#{@drop.id}"}
      phx-hook="GridCardData"
      data-drop-short-id={@drop.short_id}
    >
      <.drop_screenshot
        class="rounded-t-md"
        drop={@drop}
        page_link={~p"/d/#{@drop.short_id}"}
        red_dot_action={JS.dispatch("masonry-item-remove", detail: %{dropId: @drop.id})}
        green_dot_action={JS.navigate(~p"/d/#{@drop.short_id}")}
      />

      <div :if={!@drop.screenshot} class="py-[12px] px-[6px]">
        <.window_actions
          red_dot_action={JS.navigate(~p"/")}
          green_dot_action={JS.navigate(~p"/")}
          yellow_inactive_color="bg-gray-400"
        />
      </div>

      <div class="drop-content">
        <h3 class="drop-title">{@drop.title}</h3>
        <div class="drop-body">
          {@text}
        </div>

        <div class="flex justify-between">
          <div class="drop-meta">
            <img src={@drop.user.avatar} alt={@drop.user.github_username} class="user-avatar" />
            <a href={~p"/d/#{@drop.short_id}"} class="hidden"></a>
            <p>{@drop.user.github_username}</p>
            <p class="text-[#868686] text-xs before:content-['•'] before:mr-1">
              <.created_at drop={@drop} />
            </p>
          </div>

          <%= if @show_card_menu? do %>
            <button
              class="text-[#797979] hover:text-[#5947F1]"
              id={"drop-card-menu-btn-#{@drop.id}"}
              data-drop-id={@drop.id}
              phx-click={JS.toggle(to: "#drop-card-menu-#{@drop.id}")}
            >
              <.icon name="hero-ellipsis-horizontal" class="h-5 w-5" />
            </button>
          <% else %>
            <.drop_card_action_default id={"#{@drop.id}-main"} short_id={@drop.short_id} />
          <% end %>
        </div>
      </div>

      <.drop_card_menu author?={@drop.user_id == @user_id} id={@drop.id} short_id={@drop.short_id} />
    </div>
    """
  end

  defp created_at(assigns) do
    ~H"""
    <relative-time datetime={"#{assigns.drop.inserted_at}Z"}>
      {Timex.format!(assigns.drop.inserted_at, "{relative}", :relative)}
    </relative-time>
    """
  end

  attr :current_user, User, default: nil
  attr :drop, Drop, required: true

  @spec drop(assigns()) :: rendered()
  def drop(assigns) do
    ~H"""
    <div
      class={[
        "text-sm md:text-base leading-[1.5] relative",
        "w-[95%] md:w-[97%] max-w-md md:max-w-xl lg:max-w-3xl mx-auto",
        "border border-[#CBCBCB] rounded-xl p-3 md:p-10"
      ]}
      id={"drop-details-#{@drop.short_id}"}
      phx-mounted={JS.add_class("shadow-md shadow-[#c4c0c8]", to: ".header")}
    >
      <.drop_screenshot
        class="rounded-xl"
        drop={@drop}
        page_link={~p"/"}
        green_dot_action={JS.navigate(~p"/")}
        yellow_dot_action={JS.navigate(~p"/")}
      />

      <div :if={!@drop.screenshot} class="py-[12px] px-[6px]">
        <.window_actions
          red_dot_action={JS.navigate(~p"/")}
          green_dot_action={JS.navigate(~p"/")}
          yellow_dot_action={JS.navigate(~p"/")}
          yellow_inactive_color="bg-gray-400"
        />
      </div>

      <h1 class="font-[500] text-xl md:text-2xl mt-4">{@drop.title}</h1>

      <div class="flex gap-x-3 items-center border-b-[1.5px] border-b-[#ececec] py-3 px-3 md:px-5 -mx-2 md:-mx-5">
        <img
          src={@drop.user.avatar}
          alt={@drop.user.github_username}
          class="rounded-full h-12 w-12 object-cover"
        />
        <div>
          <p class="mb-1 flex items-center gap-x-1">
            <span>{@drop.user.github_username}</span>
            <span>•</span>
            <span class="text-[#696969] text-xs">
              <.created_at drop={@drop} />
            </span>
          </p>
        </div>
      </div>

      <div
        class="leading-[1.6] grid w-full py-3 drop-full-content"
        id="drop-body"
        phx-hook="DropBodyContainer"
      >
        {to_html(@drop.body)}
      </div>

      <p
        id="copy-link-#{@drop.id}"
        data-clipboard-text={url(~p"/d/#{@drop.short_id}")}
        phx-hook="CopyToClipboard"
        class={[
          "py-3 px-3 md:px-5 mt-4 -mx-2 md:-mx-5",
          "text-sm text-[#4f4f4f] hover:text-[#5947F1] border-y-[1px] border-y-[#dddddd] cursor-pointer",
          "flex items-center justify-end gap-x-2"
        ]}
      >
        <span><.icon name="hero-link" class="h-4 w-4 stroke-2" /></span>
        <span class="opacity-75">Copy link</span>
      </p>

      <.link
        :if={@current_user && @current_user.id == @drop.user_id}
        navigate={~p"/drops/#{@drop.short_id}/edit"}
        class="mt-4 text-sm text-[#4f4f4f] hover:text-[#5947F1] flex items-center justify-center gap-x-2 py-2"
      >
        <.icon name="hero-pencil" class="h-4 w-4 stroke-2" />
        <span>Edit</span>
      </.link>

      <.copy_prompt />
    </div>
    """
  end

  attr :drop, Drop, required: true
  attr :class, :string, default: nil
  attr :page_link, :string, default: nil
  attr :active?, :boolean, default: false
  attr :red_dot_action, :any, default: nil
  attr :green_dot_action, :any, default: nil
  attr :yellow_dot_action, :any, default: nil

  defp drop_screenshot(assigns) do
    ~H"""
    <div :if={@drop.screenshot} class={["screenshot-wrapper", @class]}>
      <div :if={@drop.screenshot.internal_url} class="screenshot-header">
        <.window_actions
          green_dot_action={@green_dot_action}
          red_dot_action={@red_dot_action}
          yellow_dot_action={@yellow_dot_action}
        />
      </div>
      <img
        :if={@drop.screenshot && @drop.screenshot.internal_url}
        src={@drop.screenshot.internal_url}
        class="screenshot-image"
        id={"drop-image:#{@drop.id}"}
      />
    </div>
    """
  end

  attr :green_dot_action, :any, default: nil
  attr :red_dot_action, :any, default: nil
  attr :rest, :global
  attr :has_screenshot?, :boolean, default: true
  attr :yellow_dot_action, :any, default: nil
  attr :yellow_inactive_color, :string, default: "bg-white"

  defp window_actions(assigns) do
    dots_config = [
      %{
        type: :red,
        action: assigns.red_dot_action,
        color_class: "red-dot",
        bg_color: "bg-[#ff5f57]",
        inactive_color: "bg-white",
        icon: :x_mark
      },
      %{
        type: :yellow,
        action: assigns.yellow_dot_action,
        color_class: "yellow-dot",
        bg_color: "bg-[#efd342]",
        inactive_color: assigns.yellow_inactive_color,
        icon: :minus
      },
      %{
        type: :green,
        action: assigns.green_dot_action,
        color_class: "green-dot",
        bg_color: "bg-[#28ca42]",
        inactive_color: "bg-white",
        icon: :expand
      }
    ]

    assigns = assign(assigns, :dots_config, dots_config)

    ~H"""
    <div class="flex items-center gap-x-1" {@rest}>
      <.window_dot
        :for={dot <- @dots_config}
        action={dot.action}
        color_class={dot.color_class}
        bg_color={dot.bg_color}
        inactive_color={dot.inactive_color}
        icon_type={dot.icon}
      />
    </div>
    """
  end

  attr :action, :any
  attr :color_class, :string
  attr :bg_color, :string
  attr :inactive_color, :string, default: "bg-white"
  attr :icon_type, :atom

  defp window_dot(assigns) do
    ~H"""
    <div
      class={[
        "w-3 h-3 rounded-full flex items-center justify-center group",
        @color_class,
        @action && @bg_color,
        !@action && @inactive_color
      ]}
      phx-click={@action}
    >
      <.window_dot_icon icon_type={@icon_type} show_icon={!!@action} />
    </div>
    """
  end

  attr :icon_type, :atom, required: true
  attr :show_icon, :boolean, required: true

  defp window_dot_icon(%{icon_type: :x_mark} = assigns) do
    ~H"""
    <.icon
      name="hero-x-mark-solid"
      class={[
        "h-2 w-2 hidden",
        @show_icon && "group-hover:block"
      ]}
    />
    """
  end

  defp window_dot_icon(%{icon_type: :minus} = assigns) do
    ~H"""
    <.icon
      name="hero-minus"
      class={[
        "h-2 w-2 hidden",
        @show_icon && "group-hover:block"
      ]}
    />
    """
  end

  defp window_dot_icon(%{icon_type: :expand} = assigns) do
    ~H"""
    <svg
      width="6"
      height="6"
      viewBox="0 0 8 8"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      class={[
        "hidden",
        @show_icon && "group-hover:block"
      ]}
    >
      <path d="M1 1V6.33333L6.33333 1H1Z" fill="#247523" />
      <path d="M7 7H1.66667L7 1.66667V7Z" fill="#247523" />
    </svg>
    """
  end

  attr :condition, :boolean, required: true

  @spec welcome_message(assigns()) :: rendered()
  def welcome_message(assigns) do
    ~H"""
    <div
      :if={@condition}
      class="text-[#EAE8FD] text-sm bg-gradient-to-r from-[#4b37f0] via-[#5f4ef2] to-[#6e5ff3] py-4 pb-6 full-width welcome-message px-12"
      id="welcome-message"
      phx-hook="WelcomeMessage"
    >
      <div class="w-full flex justify-end items-center">
        <button class="ml-auto breakout" phx-click={hide_welcome_message()}>
          <.icon name="hero-x-mark-solid" class="h-8 w-8 border" />
        </button>
      </div>

      <h2 class="breakout font-[500] text-[20px] tracking-wide mb-3 md:ml-3">
        Welcome to ElixirDrops!
      </h2>

      <p class="breakout md:ml-3 text-[16px] tracking-wide leading-[24px]">
        Hello there and welcome to the ultimate hub for the Elixir community!
        Whether you're a seasoned developer or just starting your journey, ElixirDrops is the perfect place to discover, share, and discuss the best tips and tricks for mastering Elixir.
        Sign in to explore, learn and become a contributor on this platform.
      </p>
    </div>
    """
  end

  attr :current_user, User, required: true
  attr :search_query, :string, default: ""
  attr :show_suggestions, :boolean, default: false
  attr :search_suggestions, :list, default: []
  attr :show_profile_suggestions, :boolean, default: false
  attr :profile_search_suggestions, :list, default: []

  @spec user_drops_header(assigns()) :: rendered()
  def user_drops_header(assigns) do
    ~H"""
    <div class="full-width" phx-mounted={JS.remove_class("shadow-md shadow-[#c4c0c8]", to: ".header")}>
      <div class="text-[#EAE8FD] text-xl bg-gradient-to-r from-[#4b37f0] via-[#5f4ef2] to-[#6e5ff3] py-6 md:pl-6">
        <div class="flex flex-col md:flex-row items-center gap-x-3 breakout md:pl-6">
          <div>
            <img
              src={@current_user.avatar}
              alt={@current_user.github_username}
              class="w-16 h-16 rounded-full object-fill"
            />
          </div>
          <p>
            {@current_user.github_username}
          </p>
        </div>
      </div>

      <nav class="md:pl-20 bg-[#f6f6f6] shadow-md shadow-[#cfcdd2] nav-secondary">
        <div class="flex items-center px-4 md:px-0">
          <ul class="flex items-center" id="secondary-nav-links">
            <li class="min-h-full py-4 border-b-2 border-b-[#887ce1] flex items-center mr-8">
              <.link href={~p"/profile"}>
                My drops
              </.link>
            </li>
            <!-- User Profile Search Input -->
            <li class="min-h-full py-4 border-b-2 border-b-transparent hover:border-b-gray-300 flex items-center">
              <div id="profile-search-input" class="relative" phx-hook="SearchSuggestions">
                <form
                  phx-submit={JS.push("search_submit") |> JS.hide(to: "#profile-search-dropdown")}
                  class="relative flex items-center"
                >
                  <.icon name="hero-magnifying-glass" class="absolute left-3 h-4 w-4 text-gray-500" />
                  <label for="profile-search-query" class="sr-only">Search your drops</label>
                  <input
                    id="profile-search-query"
                    type="text"
                    name="query"
                    value={@search_query}
                    placeholder="Search drops"
                    phx-change="load_suggestions"
                    class={[
                      "pl-10 pr-4 py-2 bg-transparent border-0",
                      "focus:outline-none focus:ring-0 placeholder-gray-500 text-sm",
                      "min-w-[200px]"
                    ]}
                  />
                </form>
                <!-- Search Suggestions Dropdown -->
                <div
                  :if={@show_profile_suggestions and length(@profile_search_suggestions) > 0}
                  id="profile-search-dropdown"
                  class={[
                    "absolute top-full left-0 mt-1 bg-white rounded-lg shadow-lg border border-gray-200 z-50",
                    "max-h-80 overflow-y-auto min-w-[200px]"
                  ]}
                >
                  <div class="py-2">
                    <div
                      :for={suggestion <- @profile_search_suggestions}
                      class="px-4 py-2 hover:bg-gray-50 cursor-pointer group"
                      tabindex="0"
                      phx-click={
                        JS.push("search_submit", value: %{query: suggestion.query})
                        |> JS.hide(to: "#profile-search-dropdown")
                      }
                    >
                      <div class="flex items-center justify-between">
                        <div class="flex items-center gap-2">
                          <.icon
                            :if={suggestion.type == :history}
                            name="hero-clock"
                            class="h-4 w-4 text-gray-400"
                          />
                          <.icon
                            :if={suggestion.type == :popular}
                            name="hero-magnifying-glass"
                            class="h-4 w-4 text-gray-400"
                          />
                          <span class="text-sm text-gray-900">{suggestion.query}</span>
                        </div>
                        <button
                          :if={suggestion.type == :history}
                          type="button"
                          tabindex="0"
                          phx-click={
                            JS.push("delete_search_history", value: %{id: suggestion.id})
                            |> JS.show(to: "#profile-search-dropdown")
                          }
                          class="opacity-0 group-hover:opacity-100 p-1 text-gray-400 hover:text-gray-600"
                        >
                          <.icon name="hero-trash" class="h-3 w-3" />
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </li>
          </ul>
        </div>
      </nav>
    </div>
    """
  end

  @spec signin_popup_message(assigns()) :: rendered()
  def signin_popup_message(assigns) do
    ~H"""
    <div
      id="signin-popup-message"
      class={[
        "hidden bg-white absolute rounded-lg shadow-md shadow-[#b2b2b2] z-[10000] grid",
        "top-[50%] left-[50%] translate-x-[-50%] translate-y-[-50%]",
        "w-[95%] md:w-[40%] py-4 md:py-6 px-4"
      ]}
      phx-click-away={hide_popup("signin-popup-message")}
    >
      <button class="ml-auto" phx-click={hide_popup("signin-popup-message")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5" />
      </button>
      <div class="mx-auto mb-4">
        <img src={~p"/images/logo.png"} />
      </div>
      <p class="text-sm md:text-base mx-auto mb-6">
        Take a moment to sign in to continue on ElixirDrops!
      </p>
      <.link
        href={~p"/auth/github"}
        class="font-semibold text-[#eae8fd] text-sm md:text-base bg-blue_primary hover:opacity-80 w-[55%] md:w-[45%] py-2 md:py-2 mx-auto rounded-lg flex justify-center items-center gap-x-2"
      >
        <span><Icons.github_icon /></span>
        <span> Sign in with GitHub</span>
      </.link>
    </div>
    """
  end

  @spec cancel_form_popup_message(assigns()) :: rendered()
  def cancel_form_popup_message(assigns) do
    ~H"""
    <div
      :if={@current_user}
      id="edit-form-cancel-confirm"
      class={[
        "hidden bg-white absolute rounded-lg shadow-md shadow-[#b2b2b2] z-[10000] grid",
        "top-[50%] left-[50%] translate-x-[-50%] translate-y-[-50%]",
        "w-[95%] md:w-[60%] py-4 md:py-8 px-4 md:px-6"
      ]}
      phx-click-away={hide_popup("edit-form-cancel-confirm")}
    >
      <div class="grid gap-y-2">
        <.icon name="hero-exclamation-triangle" class="text-[#efd343] h-8 w-8 mx-auto" />
        <h3 class="font-semibold text-xl text-[#252525] mx-auto">Wait a minute!</h3>
        <p class="mx-auto">
          Are you sure you want to leave this page? All changes you've made will be lost.
        </p>
        <div class="flex justify-center items-center gap-x-3 mx-auto w-full">
          <.link
            id="confirm-close-editor-button"
            navigate={~p"/profile"}
            class="text-[#4f4f4f] text-sm text-center rounded-lg w-[30%] py-2 bg-[#eeeeee] hover:bg-[#eae8fd]"
            phx-click={hide_popup("edit-form-cancel-confirm")}
          >
            Close editor
          </.link>
          <button
            type="button"
            class="text-sm text-[#d3cffb] rounded-lg w-[30%] py-2 bg-blue_primary hover:opacity-80"
            phx-click={hide_popup("edit-form-cancel-confirm")}
          >
            Continue writing
          </button>
        </div>
      </div>
    </div>
    """
  end

  @spec copied_link_popup_message(assigns()) :: rendered()
  def copied_link_popup_message(assigns) do
    ~H"""
    <p
      id="copy-confirm-message"
      class={[
        "hidden text-[#eae8fd] text-xs bg-[#9666d9] rounded-lg drop-shadow-sm px-3 py-3 flex items-center gap-x-1 z-[1000]",
        "fixed bottom-12 left-[50%] translate-x-[-50%] translate-y-[50%]"
      ]}
    >
      <.icon name="hero-check-circle-solid bg-[#b2b2b2]" class="h-4 w-4 fill-[#eae8fd] bg-[#eae8fd]" />
      <span>copied to clipboard</span>
    </p>
    """
  end

  attr :current_user, User
  attr :class, :string, default: nil

  @spec create_drop_button_mobile(assigns()) :: rendered()
  def create_drop_button_mobile(assigns) do
    ~H"""
    <.link
      id="create-drop-btn-mobile"
      phx-hook="CreateDropButtonMobile"
      class={[
        "bg-[#2f19ee] h-10 w-10 rounded-full fixed bottom-4 right-3 z-[10000] md:hidden flex items-center justify-center hover:opacity-80",
        @class
      ]}
      phx-click={
        if(@current_user,
          do: JS.navigate(~p"/drops/new"),
          else: show_popup("signin-popup-message")
        )
      }
    >
      <.icon name="hero-plus" class="text-[#eae8fd] h-5 w-5" />
    </.link>
    """
  end

  attr :id, :string, required: true
  attr :progress_value, :integer, default: 0
  attr :screenshot, :map, required: true
  attr :target, :any, required: true

  @spec generating_screenshots_popup(assigns()) :: rendered()
  def generating_screenshots_popup(assigns) do
    ~H"""
    <div
      :if={@screenshot.status != :skipped}
      class="bg-white absolute rounded-lg shadow-md shadow-[#b2b2b2] z-[10000] grid top-[48%] left-[50%] translate-x-[-50%] translate-y-[-50%] w-[90%] md:w-[80%] lg:max-w-[45em]"
      id={@id}
      phx-click-away={hide_popup(@id)}
      phx-hook="ScreenshotProgress"
      phx-target={@target}
    >
      <button id="close-screenshot-progress" class="bg-black" phx-click={hide_popup(@id)}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 text-gray-600 absolute top-2 right-2" />
      </button>
      <div class="bg-white rounded-lg py-8 text-sm md:text-base text-black text-center mx-auto min-h-[200px] md:min-h-[500px] min-w-[300px] flex flex-col justify-between items-center">
        <p
          :if={@screenshot.status != :completed}
          class="w-[75%] text-sm md:text-base lg:text-lg mx-auto mb-2 font-light"
        >
          Your drop is almost ready! You can close this modal—your drop will continue processing in the background.
        </p>
        <p
          :if={@screenshot.status == :completed}
          class="text-gray-700 font-normal text-lg md:text-xl lg:text-2xl mx-auto"
        >
          Here's your screenshot!
          <span class="text-sm md:text-base lg:text-lg block font-light">
            You can now view and share your drop
          </span>
        </p>

        <div class={[
          "pt-8 min-w-[80%] mx-auto",
          @screenshot.status != :completed &&
            "flex h-[80%] bg-gradient-to-b rounded-lg from-[#4f42d2] to-[#8149d2] my-auto"
        ]}>
          <div
            :if={@screenshot.status != :completed}
            class="mx-auto text-white rounded-lg flex flex-col items-center justify-center space-y-4"
          >
            <.progress_loader />
            <p class="text-base md:text-lg lg:text-xl text-white mx-auto mt-4 mb-6">
              Generating Code Screenshots...
            </p>
          </div>
          <img
            :if={@screenshot.status == :completed}
            src={"#{@screenshot.url}?t=#{System.os_time(:millisecond)}"}
            class="max-w-[80%] rounded-xl mx-auto"
            alt="Generated code screenshot"
          />

          <div
            :if={@screenshot.status == :completed}
            class="text-xs md:text-sm flex justify-center gap-x-4 mt-4"
          >
            <.link
              type="button"
              class="text-[#4f4f4f] rounded-lg py-2 px-4 bg-[#eeeeee] hover:bg-[#eae8fd]"
              phx-click={hide_popup("generating-screenshots-popup")}
              navigate={~p"/drops/#{@screenshot.drop_short_id}/edit"}
            >
              Edit drop
            </.link>
            <.link
              type="button"
              class="text-[#d3cffb] rounded-lg py-2 px-4 bg-blue_primary hover:opacity-80"
              navigate={~p"/profile"}
            >
              View drops
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp copy_prompt(assigns) do
    ~H"""
    <template id="copy-prompt-template">
      <div class="copy-prompt">
        <svg
          width="20"
          height="22"
          viewBox="0 0 20 22"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          class="copy-svg"
        >
          <path
            fill-rule="evenodd"
            clip-rule="evenodd"
            d="M13 0.25H8.944C7.106 0.25 5.65 0.25 4.511 0.403C3.339 0.561 2.39 0.893 1.641 1.641C0.893 2.39 0.561 3.339 0.403 4.511C0.25 5.651 0.25 7.106 0.25 8.944V15C0.250024 15.8934 0.568936 16.7575 1.14934 17.4367C1.72974 18.1159 2.53351 18.5657 3.416 18.705C3.553 19.469 3.818 20.121 4.348 20.652C4.95 21.254 5.708 21.512 6.608 21.634C7.475 21.75 8.578 21.75 9.945 21.75H13.055C14.422 21.75 15.525 21.75 16.392 21.634C17.292 21.512 18.05 21.254 18.652 20.652C19.254 20.05 19.512 19.292 19.634 18.392C19.75 17.525 19.75 16.422 19.75 15.055V9.945C19.75 8.578 19.75 7.475 19.634 6.608C19.512 5.708 19.254 4.95 18.652 4.348C18.121 3.818 17.469 3.553 16.705 3.416C16.5657 2.53351 16.1159 1.72974 15.4367 1.14934C14.7575 0.568936 13.8934 0.250024 13 0.25ZM15.13 3.271C14.9779 2.827 14.6909 2.44166 14.3089 2.16893C13.927 1.89619 13.4693 1.74971 13 1.75H9C7.093 1.75 5.739 1.752 4.71 1.89C3.705 2.025 3.125 2.279 2.702 2.702C2.279 3.125 2.025 3.705 1.89 4.711C1.752 5.739 1.75 7.093 1.75 9V15C1.75 15.4693 1.89619 15.927 2.16892 16.3089C2.44166 16.6908 2.827 16.9779 3.271 17.13C3.25 16.52 3.25 15.83 3.25 15.055V9.945C3.25 8.578 3.25 7.475 3.367 6.608C3.487 5.708 3.747 4.95 4.348 4.348C4.95 3.746 5.708 3.488 6.608 3.367C7.475 3.25 8.578 3.25 9.945 3.25H13.055C13.83 3.25 14.52 3.25 15.13 3.271ZM5.408 5.41C5.685 5.133 6.073 4.953 6.808 4.854C7.562 4.753 8.564 4.751 9.999 4.751H12.999C14.434 4.751 15.435 4.753 16.191 4.854C16.925 4.953 17.313 5.134 17.59 5.41C17.867 5.687 18.047 6.075 18.146 6.81C18.247 7.564 18.249 8.566 18.249 10.001V15.001C18.249 16.436 18.247 17.437 18.146 18.193C18.047 18.927 17.866 19.315 17.59 19.592C17.313 19.869 16.925 20.049 16.19 20.148C15.435 20.249 14.434 20.251 12.999 20.251H9.999C8.564 20.251 7.562 20.249 6.807 20.148C6.073 20.049 5.685 19.868 5.408 19.592C5.131 19.315 4.951 18.927 4.852 18.192C4.751 17.437 4.749 16.436 4.749 15.001V10.001C4.749 8.566 4.751 7.564 4.852 6.809C4.951 6.075 5.132 5.687 5.408 5.41Z"
            fill="#CBCBCB"
          />
        </svg>

        <svg
          width="20"
          height="20"
          viewBox="0 0 20 20"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          class="copied-svg hidden"
        >
          <path
            d="M7 10L9 12L13 8M19 10C19 14.9706 14.9706 19 10 19C5.02944 19 1 14.9706 1 10C1 5.02944 5.02944 1 10 1C14.9706 1 19 5.02944 19 10Z"
            stroke="#B2B2B2"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </div>
    </template>
    """
  end

  defp progress_loader(assigns) do
    ~H"""
    <div class="relative w-20 h-20 md:w-24 md:h-24 flex items-center justify-center">
      <svg class="h-20 w-20 md:h-24 md:w-24" viewBox="0 0 100 100">
        <circle
          class="progress-background"
          cx="50"
          cy="50"
          r="45"
          stroke="#dddddd"
          stroke-width="8"
          fill="none"
        >
        </circle>
        <circle
          class="progress-bar"
          cx="50"
          cy="50"
          r="45"
          id="progress-circle"
          stroke="#ffffff"
          stroke-width="8"
          stroke-dasharray="282.7"
          stroke-dashoffset="282.7"
          fill="none"
        >
        </circle>
      </svg>
      <div class="percentage" id="percentage">0%</div>
    </div>
    """
  end

  defp create_drop_button(assigns) do
    ~H"""
    <.link
      class={[
        "text-sm tracking-wide px-6 py-2 rounded-lg hidden md:flex items-center gap-x-2",
        @current_user && "text-[#eae8fd] bg-blue_primary hover:opacity-80",
        !@current_user && "text-blue_primary border-blue_primary border-2 hover:bg-[#eae8fd]"
      ]}
      id="create-drop-button"
      phx-click={
        if @current_user,
          do: JS.navigate(~p"/drops/new"),
          else: show_popup("signin-popup-message")
      }
    >
      <span><.icon name="hero-plus" /></span>
      <span>Create Drop</span>
    </.link>
    """
  end

  defp drop_card_menu(assigns) do
    ~H"""
    <div
      class="drop-card-menu text-sm md:text-base hidden absolute right-6 top-[8rem] md:top-[9rem] py-6 pl-6 pr-12 rounded-md bg-white shadow-xl shadow-[#aaa4af] z-[100000]"
      id={"drop-card-menu-#{@id}"}
      phx-click-away={JS.hide(to: "#drop-card-menu-#{@id}")}
    >
      <.drop_card_action_default id={"#{@id}-menu"} short_id={@short_id}>
        <:inner_text>
          Copy link
        </:inner_text>
      </.drop_card_action_default>

      <.link
        :if={@author?}
        navigate={"/drops/#{@short_id}/edit"}
        class="text-[#797979] hover:text-[#5947F1] flex items-center justify-center gap-x-2 mt-6"
        id={"edit-drop-#{@id}"}
      >
        <.icon name="hero-pencil" class="h-4 md:h-6 w-4 md:w-6" /> Edit drop
      </.link>
    </div>
    """
  end

  defp slide_menu(assigns) do
    ~H"""
    <div
      class="hidden w-[100%] md:w-[25%] shadow-md shadow-[#c4c1c8] md:rounded-b-md pt-10 pb-4 absolute top-[101%] right-0 md:right-[2rem] grid z-[10000] bg-white"
      id="slide-menu"
      phx-click-away={JS.toggle_class("hidden", to: "#slide-menu")}
    >
      <div class="mx-auto cursor-default">
        <img
          src={@current_user.avatar}
          alt={@current_user.github_username}
          class="w-16 h-16 rounded-full"
        />
      </div>
      <p class="text-[1.2rem] mx-auto mt-1 cursor-default">{@current_user.github_username}</p>

      <ul class="mt-10 grid gap-y-6">
        <li class="px-5">
          <.link
            href={~p"/profile"}
            class="flex gap-x-2 hover:text-[#5947F1]"
            id="view-user-drops-link"
          >
            <span><Icons.drops_icon /></span>
            <span> My drops </span>
          </.link>
        </li>
        <li class="nav-list-border full-bleed"></li>
        <li class="px-5">
          <.link href={~p"/auth/logout"} class="flex gap-x-2 hover:text-[#5947F1]">
            <span><Icons.sign_out_icon /></span>
            <span>Sign out</span>
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :short_id, :string, required: true

  slot :inner_text

  defp drop_card_action_default(assigns) do
    ~H"""
    <div
      id={"card-copy-link-#{@id}"}
      data-clipboard-text={url(~p"/d/#{@short_id}")}
      phx-hook="CopyToClipboard"
      class={[
        "text-[#797979] hover:text-[#5947F1]",
        @inner_text && "flex items-center justify-center gap-x-2"
      ]}
    >
      <.icon name="hero-link-solid" class="h-4 w-4 md:h-6 md:w-6" />
      {render_slot(@inner_text)}
    </div>
    """
  end

  defp hide_welcome_message do
    %JS{}
    |> JS.hide(to: "#welcome-message")
    |> JS.add_class("shadow-md shadow-[#c4c0c8]", to: ".header")
    |> JS.dispatch("hide-welcome-message", to: "#welcome-message")
  end

  @spec show_popup(String.t()) :: Phoenix.LiveView.JS.t()
  def show_popup(pop_up_message_id) do
    %JS{}
    |> JS.remove_class("hidden", to: "##{pop_up_message_id}")
    |> JS.add_class("show-pop-up", to: ".drops-container")
    |> JS.add_class("show-pop-up", to: ".drop-form")
  end

  @spec hide_popup(String.t()) :: Phoenix.LiveView.JS.t()
  def hide_popup(pop_up_message_id) do
    %JS{}
    |> JS.add_class("hidden", to: "##{pop_up_message_id}")
    |> JS.remove_class("show-pop-up", to: ".drops-container")
    |> JS.remove_class("show-pop-up", to: ".drop-form")
    |> JS.add_class("hidden", to: ".drops-editor-overlay")
  end

  @spec to_html(binary()) :: Phoenix.HTML.safe()
  def to_html(markdown) do
    markdown
    |> MDEx.to_html(
      features: [syntax_highlight_theme: "onedark"],
      extension: [
        strikethrough: true,
        underline: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true,
        shortcodes: true
      ],
      parse: [
        smart: true,
        relaxed_tasklist_matching: true,
        relaxed_autolinks: true
      ],
      render: [
        github_pre_lang: true,
        escape: true
      ]
    )
    |> raw()
  end

  @spec loading_spinner(map()) :: Phoenix.LiveView.Rendered.t()
  def loading_spinner(assigns) do
    ~H"""
    <svg
      class="animate-spin h-8 w-8 text-white"
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
    >
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
      </circle>
      <path
        class="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
      >
      </path>
    </svg>
    """
  end

  defp get_preview_text(markdown) do
    code_block_pos =
      case Regex.run(~r/```/, markdown, return: :index) do
        [{start_pos, _}] -> start_pos
        _no_match -> nil
      end

    if code_block_pos && code_block_pos <= 150 do
      markdown
      |> String.slice(0, code_block_pos)
      |> String.trim()
      |> strip_markdown()
      |> maybe_add_ellipsis()
    else
      markdown
      |> strip_markdown()
      |> truncate_text(150)
    end
  end

  defp truncate_text(text, max_length) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end

  defp maybe_add_ellipsis(text) do
    if text == "" do
      text
    else
      text <> "..."
    end
  end

  defp strip_markdown(text) do
    text
    # Remove links but keep the text
    |> String.replace(~r/\[([^\]]+)\]\([^)]+\)/, "\\1")
    # Remove bold emphasis markers (** or __)
    |> String.replace(~r/(\*\*|__)(.*?)\1/, "\\2")
    # Remove italic emphasis markers (* or _) but only when they wrap words
    # This preserves underscores in snake_case names
    |> String.replace(~r/(?<!\w)\*([^\*]+)\*(?!\w)/, "\\1")
    |> String.replace(~r/(?<!\w)_([^_]+)_(?!\w)/, "\\1")
    # Remove headers
    |> String.replace(~r/^#+\s+/m, "")
    # Remove blockquotes
    |> String.replace(~r/^>\s+/m, "")
    # Remove horizontal rules
    |> String.replace(~r/^---+$/m, "")
    # Remove inline code
    |> String.replace(~r/`([^`]+)`/, "\\1")
    # Clean up extra whitespace
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end

  attr :search_query, :string, required: true
  attr :show_suggestions, :boolean, required: true
  attr :search_suggestions, :list, required: true
  attr :current_user, User

  @spec search_input_desktop(assigns()) :: rendered()
  def search_input_desktop(assigns) do
    ~H"""
    <div id="desktop-search-input" class="relative w-full" phx-hook="SearchSuggestions">
      <form
        phx-submit={JS.push("navbar_search_submit") |> JS.hide(to: "#navbar-search-dropdown")}
        class="relative"
      >
        <label for="desktop-search-query" class="sr-only">Search drops</label>
        <input
          id="desktop-search-query"
          type="text"
          name="query"
          value={@search_query}
          placeholder="Search drops"
          phx-change="load_navbar_suggestions"
          class={[
            "w-full px-4 py-2 pl-10 pr-10 bg-white rounded-lg",
            "border border-gray-200 focus:border-[#5947F1] focus:ring-1 focus:ring-[#5947F1]",
            "placeholder-gray-500 text-sm"
          ]}
        />
        <.icon
          name="hero-magnifying-glass"
          class="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400"
        />
        <button
          :if={@search_query != ""}
          type="button"
          phx-click="clear_search"
          class="absolute right-3 top-1/2 -translate-y-1/2 p-1 hover:bg-gray-100 rounded"
        >
          <.icon name="hero-x-mark" class="h-4 w-4 text-gray-400 hover:text-gray-600" />
        </button>
      </form>
      <!-- Search Suggestions Dropdown -->
      <div
        :if={@show_suggestions and length(@search_suggestions) > 0}
        id="navbar-search-dropdown"
        class={[
          "absolute top-full left-0 right-0 mt-1 bg-white rounded-lg shadow-lg border border-gray-200 z-50",
          "max-h-80 overflow-y-auto"
        ]}
      >
        <div class="py-2">
          <div
            :for={suggestion <- @search_suggestions}
            class="px-4 py-2 hover:bg-gray-50 cursor-pointer group"
            tabindex="0"
            phx-click={
              JS.push("navbar_search_submit", value: %{query: suggestion.query})
              |> JS.hide(to: "#navbar-search-dropdown")
            }
          >
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <.icon
                  :if={suggestion.type == :history}
                  name="hero-clock"
                  class="h-4 w-4 text-gray-400"
                />
                <.icon
                  :if={suggestion.type == :popular}
                  name="hero-magnifying-glass"
                  class="h-4 w-4 text-gray-400"
                />
                <span class="text-sm text-gray-800">{suggestion.query}</span>
              </div>
              <button
                :if={suggestion.type == :history}
                type="button"
                tabindex="0"
                class="opacity-0 group-hover:opacity-100 p-1 hover:bg-gray-200 rounded"
                phx-click={
                  JS.push("delete_navbar_search_history", value: %{id: suggestion.id})
                  |> JS.show(to: "#navbar-search-dropdown")
                }
              >
                <.icon name="hero-trash" class="h-3 w-3 text-gray-500" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :search_query, :string, required: true
  attr :show_suggestions, :boolean, required: true
  attr :search_suggestions, :list, required: true
  attr :current_user, User

  @spec search_overlay_mobile(assigns()) :: rendered()
  def search_overlay_mobile(assigns) do
    ~H"""
    <div
      id="search-overlay"
      class="hidden fixed top-0 left-0 right-0 z-50 bg-white shadow-lg"
      phx-hook="MobileSearchOverlay"
    >
      <!-- Search bar matching Figma design -->
      <div id="mobile-search-wrapper" class="relative">
        <div
          id="mobile-search-input"
          class="flex items-center gap-4 px-4 py-3 bg-white"
          phx-hook="SearchSuggestions"
        >
          <button
            class="p-1 text-gray-600 hover:text-gray-900"
            phx-click={JS.hide(to: "#search-overlay")}
          >
            <.icon name="hero-arrow-left" class="h-6 w-6" />
          </button>

          <form
            phx-submit={JS.push("search_submit") |> JS.hide(to: "#search-overlay")}
            class="flex-1 relative"
          >
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search drops"
              phx-change="load_suggestions"
              phx-focus="focus_search_input"
              phx-blur="blur_search_input"
              class={[
                "w-full px-4 py-2 pl-10 pr-10 bg-white rounded-lg",
                "border border-gray-200 focus:border-[#5947F1] focus:ring-1 focus:ring-[#5947F1]",
                "placeholder-gray-500 text-base"
              ]}
              autofocus
            />
            <.icon
              name="hero-magnifying-glass"
              class="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400"
            />
            <button
              :if={@search_query != ""}
              type="button"
              phx-click="clear_search"
              class="absolute right-3 top-1/2 -translate-y-1/2 p-1 hover:bg-gray-100 rounded"
            >
              <.icon name="hero-x-mark" class="h-5 w-5 text-gray-400 hover:text-gray-600" />
            </button>
          </form>
        </div>
        <!-- Search Suggestions -->
        <div
          :if={@show_suggestions and length(@search_suggestions) > 0}
          id="mobile-search-dropdown"
          class="absolute top-full left-0 right-0 bg-white border-t border-gray-200 max-h-80 overflow-y-auto"
        >
          <div
            :for={suggestion <- @search_suggestions}
            class="px-4 py-3 hover:bg-gray-50 cursor-pointer group"
            tabindex="0"
            phx-click="search_submit"
            phx-value-query={suggestion.query}
          >
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-3">
                <.icon
                  :if={suggestion.type == :history}
                  name="hero-clock"
                  class="h-5 w-5 text-gray-400"
                />
                <.icon
                  :if={suggestion.type == :popular}
                  name="hero-magnifying-glass"
                  class="h-5 w-5 text-gray-400"
                />
                <span class="text-base text-gray-800">{suggestion.query}</span>
              </div>
              <button
                :if={suggestion.type == :history}
                type="button"
                tabindex="0"
                class="opacity-0 group-hover:opacity-100 p-2 hover:bg-gray-200 rounded"
                phx-click="delete_search_history"
                phx-value-id={suggestion.id}
                phx-stop-propagation="true"
              >
                <.icon name="hero-trash" class="h-4 w-4 text-gray-500" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :search_query, :string, required: true
  attr :suggested_searches, :list, default: []

  @spec no_results(assigns()) :: rendered()
  def no_results(assigns) do
    ~H"""
    <!-- No search results - matches Figma design exactly -->
    <div class="flex flex-col items-center justify-center min-h-[60vh] px-4 py-8">
      <div class="w-full max-w-[772px] flex flex-col items-center gap-8">
        <!-- Main Illustration - Drop Card with Magnifying Glass -->
        <div class="relative w-[392px] h-[345px] rounded-[16px]">
          <!-- Drop Card Component -->
          <div class="absolute left-1/2 top-[49px] transform -translate-x-1/2 w-[258px] bg-white rounded-[9px] shadow-[0px_3px_14px_0px_rgba(19,0,33,0.12)] p-[15px] flex flex-col gap-[19px]">
            <!-- Drop Card Background with gradient and code elements -->
            <div class="relative w-[233px] h-[150px] rounded-[13px] bg-gradient-to-b from-[#eae8fd80] from-[40%] to-[#bfb8fa66] to-[116%] overflow-hidden">
              <!-- Background decorative elements -->
              <img
                src={~p"/images/no-results-group1.svg"}
                alt=""
                class="absolute bottom-[65%] left-[0%] right-[71%] top-[-18%]"
              />
              <img
                src={~p"/images/no-results-group2.svg"}
                alt=""
                class="absolute bottom-[-9%] left-[0%] right-[75%] top-[62%]"
              />
              <img
                src={~p"/images/no-results-group3.svg"}
                alt=""
                class="absolute bottom-[-25%] left-[17%] right-[-8%] top-[-46%]"
              />
            </div>
            <!-- Code Block Representation -->
            <div class="bg-white rounded-[5px] shadow-[0px_1.78px_7.12px_0px_rgba(0,0,0,0.12)] p-[9px] flex flex-col gap-[5px]">
              <div class="bg-[#eae8fd] h-[4px] w-[212px]"></div>
              <div class="bg-[#eae8fd] h-[4px] w-[133px]"></div>
              <div class="bg-[#eae8fd] h-[4px] w-[122px]"></div>
              <div class="bg-[#eae8fd] h-[4px] w-[103px]"></div>
            </div>
          </div>
          <!-- Magnifying Glass Illustration -->
          <img
            src={~p"/images/no-results-magnifier.svg"}
            alt=""
            class="absolute bottom-[4%] left-[-7%] w-[131px] h-[81px] transform rotate-[340deg]"
          />
        </div>
        <!-- Text Content -->
        <div class="w-full flex flex-col items-center gap-8">
          <!-- Main Message -->
          <div class="w-full min-w-full text-center">
            <p class="font-normal text-[28px] leading-[40px] text-[#797979] tracking-[0.07px] mb-0">
              Sorry we couldn't find any results for this search.
            </p>
            <p class="font-normal text-[28px] leading-[40px] text-[#797979] tracking-[0.07px]">
              Try searching any of these.
            </p>
          </div>
          <!-- Suggested Search Links -->
          <div
            :if={length(@suggested_searches) > 0}
            class="flex flex-col gap-[33px] items-center justify-center w-full"
          >
            <!-- First row of suggestions -->
            <div class="flex flex-row gap-6 items-center justify-center w-full font-normal text-[20px] leading-[24px]">
              <.link
                :for={suggestion <- Enum.take(@suggested_searches, 3)}
                href={~p"/?q=#{suggestion}"}
                class="text-[#5947f1] hover:underline whitespace-nowrap"
              >
                {String.capitalize(suggestion)}
              </.link>
            </div>
            <!-- Second row of suggestions -->
            <div
              :if={length(@suggested_searches) > 3}
              class="flex flex-row gap-6 items-center justify-center font-normal text-[20px] leading-[24px]"
            >
              <.link
                :for={suggestion <- Enum.drop(@suggested_searches, 3) |> Enum.take(2)}
                href={~p"/?q=#{suggestion}"}
                class="text-[#5947f1] hover:underline whitespace-nowrap"
              >
                {String.capitalize(suggestion)}
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
