defmodule ElixirDropsWeb.DropComponents do
  @moduledoc false

  use ElixirDropsWeb, :html

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Drops.Drop
  alias ElixirDropsWeb.Icons

  @type assigns :: map()
  @type rendered :: Phoenix.LiveView.Rendered.t()

  @spec navbar(assigns()) :: rendered()
  def navbar(assigns) do
    ~H"""
    <header class="header content-grid py-2 w-full relative z-30">
      <nav class="breakout flex items-center justify-between nav-primary">
        <div>
          <.link href={~p"/"}>
            <Icons.elixir_drops_logo class="w-32 md:w-48" />
          </.link>
        </div>

        <div>
          <%= if @current_user do %>
            <div class="flex items-center gap-x-4">
              <.create_post_button current_user={@current_user} live_action={@live_action} />

              <div
                class="flex items-center gap-x-3 cursor-pointer"
                phx-click={JS.toggle_class("hidden", to: "#slide-menu")}
              >
                <img
                  src={@current_user.avatar}
                  alt={@current_user.github_username}
                  class="w-10 h-10 rounded-full"
                />
                <p class="hidden md:block"><%= @current_user.github_username %></p>
                <button class="hidden md:block">
                  <.icon name="hero-chevron-down" class="text-[#4F4F4F]" />
                </button>
                <.slide_menu current_user={@current_user} />
              </div>
            </div>
          <% else %>
            <div class="flex items-center gap-x-4">
              <.create_post_button current_user={@current_user} live_action={@live_action} />

              <.link
                href={~p"/auth/github"}
                class="font-semibold text-[#eae8fd] text-xs md:text-sm bg-blue_primary hover:opacity-80 px-2 md:px-5 py-2 rounded-lg flex items-center gap-x-2"
              >
                <span><Icons.github_icon /></span>
                <span> Sign in with GitHub</span>
              </.link>
            </div>
          <% end %>
        </div>
      </nav>
    </header>
    """
  end

  attr :drop, Drop, required: true
  attr :show_card_menu?, :boolean, default: false

  @spec drop_card(assigns()) :: rendered()
  def drop_card(assigns) do
    ~H"""
    <div class="drop-card bg-[#f6f6f6] px-6 md:px-4 py-6 md:py-8 rounded-lg shadow-md shadow-[#bebbc2] relative">
      <div>
        <div class="flex justify-between">
          <div class="flex gap-1 md:gap-2 items-center">
            <img
              src={@drop.user.avatar}
              alt={@drop.user.github_username}
              class="rounded-full h-8 md:h-10 w-8 md:w-10 object-cover"
            />
            <p><%= @drop.user.github_username %></p>
            <p class="text-[#868686] text-[0.65rem] md:text-xs before:content-['•'] before:block] before:mr-[0.02rem] md:before:mr-[0.05rem]">
              Created <.created_at drop={@drop} />
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
            <.drop_card_action_default id={@drop.id} short_id={@drop.short_id} />
          <% end %>
        </div>

        <h3 class="text-md md:text-lg font-[500] mt-2"><%= @drop.title %></h3>
      </div>

      <.drop_card_menu id={@drop.id} short_id={@drop.short_id} />
    </div>
    """
  end

  defp created_at(assigns) do
    ~H"""
    <relative-time datetime={"#{assigns.drop.inserted_at}Z"}>
      <%= Timex.format!(assigns.drop.inserted_at, "{relative}", :relative) %>
    </relative-time>
    """
  end

  attr :drop, Drop, required: true

  @spec drop(assigns()) :: rendered()
  def drop(assigns) do
    ~H"""
    <div
      class="text-sm md:text-base w-[93%] md:w-[96%] max-w-md md:max-w-xl lg:max-w-2xl mx-auto leading-[1.5] relative"
      phx-mounted={JS.add_class("shadow-md shadow-[#c4c0c8]", to: ".header")}
    >
      <h1 class="font-[500] text-2xl md:text-4xl"><%= @drop.title %></h1>
      <div class="flex gap-x-3 items-center border-b-[2.5px] border-b-[#ececec] py-5">
        <img
          src={@drop.user.avatar}
          alt={@drop.user.github_username}
          class="rounded-full h-12 w-12 object-cover"
        />
        <div>
          <p class="mb-1"><%= @drop.user.github_username %></p>
          <p class="text-[#696969] text-xs">
            Created <.created_at drop={@drop} />
          </p>
        </div>
      </div>

      <div
        class="leading-[1.6] grid w-full py-3 drop-body"
        id="drop-body"
        phx-hook="DropBodyContainer"
      >
        <%= to_html(@drop.body) %>
      </div>

      <p
        id="copy-link-#{@id}"
        data-clipboard-text={url(~p"/d/#{@drop.short_id}")}
        phx-hook="CopyToClipboard"
        class="mt-4 text-sm text-[#4f4f4f] hover:text-[#5947F1] border-y-[1px] border-y-[#dddddd] flex items-center justify-end gap-x-2 py-3 cursor-pointer"
      >
        <span><.icon name="hero-link" class="h-4 w-4 stroke-2" /></span>
        <span>Copy link</span>
      </p>

      <.copy_prompt />
    </div>
    """
  end

  attr :condition, :boolean, required: true

  @spec welcome_message(assigns()) :: rendered()
  def welcome_message(assigns) do
    ~H"""
    <div
      :if={@condition}
      class="text-[#EAE8FD] text-sm bg-gradient-to-r from-[#4c3ddb] via-[#6159be] to-[#818494] py-4 full-width welcome-message"
      id="welcome-message"
      phx-hook="WelcomeMessage"
    >
      <button class="ml-auto breakout" phx-click={hide_welcome_message()}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5" />
      </button>

      <h2 class="breakout font-[500] text-[1.15rem] tracking-wide mb-3 md:ml-3">
        Welcome to ElixirDrops!
      </h2>

      <p class="breakout md:ml-3">
        Hello there and welcome to the ultimate hub for the Elixir community!
        Whether you're a seasoned developer or just starting your journey, ElixirDrops is the perfect place to discover, share, and discuss the best tips and tricks for mastering Elixir.
        Sign in to explore, learn and become a contributor on this platform.
      </p>
    </div>
    """
  end

  attr :current_user, User, required: true

  @spec user_drops_header(assigns()) :: rendered()
  def user_drops_header(assigns) do
    ~H"""
    <div class="full-width" phx-mounted={JS.remove_class("shadow-md shadow-[#c4c0c8]", to: ".header")}>
      <div class="text-[#EAE8FD] text-xl bg-gradient-to-r from-[#4b37f0] via-[#5f4ef2] to-[#6e5ff3] py-6 full-width">
        <div class="flex flex-col md:flex-row items-center gap-x-3 breakout md:pl-6">
          <div>
            <img
              src={@current_user.avatar}
              alt={@current_user.github_username}
              class="w-16 h-16 rounded-full object-fill"
            />
          </div>
          <p>
            <%= @current_user.github_username %>
          </p>
        </div>
      </div>

      <nav class="full-width bg-[#f6f6f6] shadow-md shadow-[#cfcdd2] nav-secondary">
        <ul class="flex" id="secondary-nav-links">
          <li class="min-h-full py-4 border-b-2 border-b-[#887ce1] flex items-center">
            <.link href={~p"/profile"}>
              My posts
            </.link>
          </li>
        </ul>
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

  @spec create_post_button_mobile(assigns()) :: rendered()
  def create_post_button_mobile(assigns) do
    ~H"""
    <.link
      id="create-post-btn-mobile"
      phx-hook="CreatePostButtonMobile"
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

  @spec copy_prompt(assigns()) :: rendered()
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
            d="M13 0.25H8.944C7.106 0.25 5.65 0.25 4.511 0.403C3.339 0.561 2.39 0.893 1.641 1.641C0.893 2.39 0.561 3.339 0.403 4.511C0.25 5.651 0.25 7.106 0.25 8.944V15C0.250024 15.8934 0.568936 16.7575 1.14934 17.4367C1.72974 18.1159 2.53351 18.5657 3.416 18.705C3.553 19.469 3.818 20.121 4.348 20.652C4.95 21.254 5.708 21.512 6.608 21.634C7.475 21.75 8.578 21.75 9.945 21.75H13.055C14.422 21.75 15.525 21.75 16.392 21.634C17.292 21.512 18.05 21.254 18.652 20.652C19.254 20.05 19.512 19.292 19.634 18.392C19.75 17.525 19.75 16.422 19.75 15.055V9.945C19.75 8.578 19.75 7.475 19.634 6.608C19.512 5.708 19.254 4.95 18.652 4.348C18.121 3.818 17.469 3.553 16.705 3.416C16.5657 2.53351 16.1159 1.72974 15.4367 1.14934C14.7575 0.568936 13.8934 0.250024 13 0.25ZM15.13 3.271C14.9779 2.827 14.6909 2.44166 14.3089 2.16893C13.927 1.89619 13.4693 1.74971 13 1.75H9C7.093 1.75 5.739 1.752 4.71 1.89C3.705 2.025 3.125 2.279 2.702 2.702C2.279 3.125 2.025 3.705 1.89 4.711C1.752 5.739 1.75 7.093 1.75 9V15C1.74971 15.4693 1.89619 15.927 2.16892 16.3089C2.44166 16.6908 2.827 16.9779 3.271 17.13C3.25 16.52 3.25 15.83 3.25 15.055V9.945C3.25 8.578 3.25 7.475 3.367 6.608C3.487 5.708 3.747 4.95 4.348 4.348C4.95 3.746 5.708 3.488 6.608 3.367C7.475 3.25 8.578 3.25 9.945 3.25H13.055C13.83 3.25 14.52 3.25 15.13 3.271ZM5.408 5.41C5.685 5.133 6.073 4.953 6.808 4.854C7.562 4.753 8.564 4.751 9.999 4.751H12.999C14.434 4.751 15.435 4.753 16.191 4.854C16.925 4.953 17.313 5.134 17.59 5.41C17.867 5.687 18.047 6.075 18.146 6.81C18.247 7.564 18.249 8.566 18.249 10.001V15.001C18.249 16.436 18.247 17.437 18.146 18.193C18.047 18.927 17.866 19.315 17.59 19.592C17.313 19.869 16.925 20.049 16.19 20.148C15.435 20.249 14.434 20.251 12.999 20.251H9.999C8.564 20.251 7.562 20.249 6.807 20.148C6.073 20.049 5.685 19.868 5.408 19.592C5.131 19.315 4.951 18.927 4.852 18.192C4.751 17.437 4.749 16.436 4.749 15.001V10.001C4.749 8.566 4.751 7.564 4.852 6.809C4.951 6.075 5.132 5.687 5.408 5.41Z"
            fill="#EAE8FD"
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

  defp create_post_button(assigns) do
    ~H"""
    <.link
      class={[
        "text-sm tracking-wide px-6 py-2 rounded-lg hidden md:flex items-center gap-x-2",
        @current_user && "text-[#eae8fd] bg-blue_primary hover:opacity-80",
        !@current_user && "text-blue_primary border-blue_primary border-2 hover:bg-[#eae8fd]"
      ]}
      id="create-post-button"
      phx-click={
        if @current_user,
          do: JS.navigate(~p"/drops/new"),
          else: show_popup("signin-popup-message")
      }
    >
      <span><.icon name="hero-plus" /></span>
      <span>Create Post</span>
    </.link>
    """
  end

  defp drop_card_menu(assigns) do
    ~H"""
    <div
      class="drop-card-menu text-sm md:text-base hidden absolute right-6 top-[3rem] md:top-[3.8rem] py-6 pl-6 pr-12 rounded-md bg-white shadow-xl shadow-[#aaa4af] z-[100000]"
      id={"drop-card-menu-#{@id}"}
      phx-click-away={JS.hide(to: "#drop-card-menu-#{@id}")}
    >
      <.drop_card_action_default id={@id} short_id={@short_id}>
        <:inner_text>
          Copy link
        </:inner_text>
      </.drop_card_action_default>

      <.link
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
      <p class="text-[1.2rem] mx-auto mt-1 cursor-default"><%= @current_user.github_username %></p>

      <ul class="mt-10 grid gap-y-6">
        <li class="px-5">
          <.link
            href={~p"/profile"}
            class="flex gap-x-2 hover:text-[#5947F1]"
            id="view-user-drops-link"
          >
            <span><Icons.drops_icon /></span>
            <span> My posts </span>
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
      <%= render_slot(@inner_text) %>
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
end
