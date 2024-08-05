defmodule ElixirDropsWeb.DropsComponents do
  @moduledoc false

  use ElixirDropsWeb, :html

  alias ElixirDrops.DateTimeHelper
  alias ElixirDropsWeb.DropsComponents.Icons

  @type assigns :: map()
  @type rendered :: Phoenix.LiveView.Rendered.t()

  @spec navbar(assigns()) :: rendered()
  def navbar(assigns) do
    ~H"""
    <header class="header content-grid py-2 w-full relative z-[100000] shadow-md shadow-[#c4c0c8]">
      <nav class="breakout flex items-center justify-between nav-primary">
        <div>
          <.link href={~p"/"}>
            <Icons.elixir_drops_logo class="w-32 md:w-48" />
          </.link>
        </div>

        <div>
          <%= if @current_user do %>
            <div class="flex items-center gap-x-4">
              <.create_post_button
                current_user={@current_user}
                live_action={@live_action}
                show_user_drops?={@show_user_drops?}
              />

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
              <.create_post_button
                current_user={@current_user}
                live_action={@live_action}
                show_user_drops?={@show_user_drops?}
              />

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

  attr :avatar, :string, required: true
  attr :created_at, :string, required: true
  attr :github_username, :string, required: true
  attr :id, :string, required: true
  attr :show_user_drops?, :boolean, required: true
  attr :timezone_offset, :integer, required: true
  attr :title, :string, required: true

  @spec drop_card(assigns()) :: rendered()
  def drop_card(assigns) do
    ~H"""
    <div class="drop-card bg-[#f6f6f6] px-6 md:px-4 py-6 md:py-8 rounded-lg shadow-md shadow-[#bebbc2] relative">
      <div>
        <div class="flex justify-between">
          <div class="flex gap-1 md:gap-2 items-center">
            <img
              src={@avatar}
              alt={@github_username}
              class="rounded-full h-8 md:h-10 w-8 md:w-10 object-cover"
            />
            <p><%= @github_username %></p>
            <p class="text-[#868686] text-[0.65rem] md:text-xs before:content-['•'] before:block] before:mr-[0.02rem] md:before:mr-[0.05rem]">
              Created <%= DateTimeHelper.convert_to_relative_time(@created_at, @timezone_offset) %>
            </p>
          </div>

          <%= if @show_user_drops? do %>
            <button
              class="text-[#797979] hover:text-[#5947F1]"
              id="drop-card-menu-btn"
              data-drop-id={@id}
              phx-hook="DropCardMenu"
            >
              <.icon name="hero-ellipsis-horizontal" class="h-5 w-5" />
            </button>
          <% else %>
            <.drop_card_action_default id={@id} />
          <% end %>
        </div>

        <h3 class="text-md md:text-lg font-[500] mt-2"><%= @title %></h3>
      </div>

      <.drop_card_menu id={@id} />
    </div>
    """
  end

  attr :avatar, :string, required: true
  attr :body, :string, required: true
  attr :created_at, :string, required: true
  attr :github_username, :string, required: true
  attr :id, :string, required: true
  attr :timezone_offset, :integer, required: true
  attr :title, :string, required: true

  @spec drop(assigns()) :: rendered()
  def drop(assigns) do
    ~H"""
    <div
      class="text-sm md:text-base w-[93%] md:w-[96%] max-w-md md:max-w-xl lg:max-w-2xl mx-auto leading-[1.5] relative"
      phx-mounted={JS.add_class("shadow-md shadow-[#c4c0c8]", to: ".header")}
    >
      <h1 class="font-[500] text-2xl md:text-4xl"><%= @title %></h1>
      <div class="flex gap-x-3 items-center border-b-[2.5px] border-b-[#ececec] py-5">
        <img src={@avatar} alt={@github_username} class="rounded-full h-12 w-12 object-cover" />
        <div>
          <p class="mb-1"><%= @github_username %></p>
          <p class="text-[#696969] text-xs">
            Created <%= DateTimeHelper.convert_to_relative_time(@created_at, @timezone_offset) %>
          </p>
        </div>
      </div>

      <div
        class="leading-[1.6] grid w-full py-3 drop-body"
        id="drop-body"
        phx-hook="DropBodyContainer"
      >
        <%= to_html(@body) %>
      </div>

      <p
        id="copy-link-#{@id}"
        data-clipboard-text={url(~p"/drops/#{@id}")}
        phx-hook="CopyToClipboard"
        class="mt-4 text-sm text-[#4f4f4f] hover:text-[#5947F1] border-y-[1px] border-y-[#dddddd] flex items-center justify-end gap-x-2 py-3 cursor-pointer"
      >
        <span><.icon name="hero-link" class="h-4 w-4 stroke-2" /></span>
        <span>Copy link</span>
      </p>
    </div>
    """
  end

  attr :condition, :boolean, required: true

  @spec welcome_message(assigns()) :: rendered()
  def welcome_message(assigns) do
    ~H"""
    <div
      :if={!@condition}
      class="text-[#EAE8FD] text-sm bg-gradient-to-r from-[#4c3ddb] via-[#6159be] to-[#818494] py-4 full-width"
      id="welcome-message"
      phx-mounted={JS.remove_class("shadow-md shadow-[#c4c0c8]", to: ".header")}
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

  attr :current_user, :any, required: true
  attr :show_user_drops?, :boolean, required: true

  @spec user_drops_header(assigns()) :: rendered()
  def user_drops_header(assigns) do
    ~H"""
    <div
      :if={@show_user_drops? && @current_user}
      class="full-width"
      phx-mounted={JS.remove_class("shadow-md shadow-[#c4c0c8]", to: ".header")}
    >
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
        <ul class="breakout flex" id="secondary-nav-links" phx-hook="SecondaryNavLinks">
          <li class="min-h-full py-4 border-b-2 border-b-[#887ce1] flex items-center">
            <.link href={~p"/#{@current_user.github_username}"}>
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
        "w-[95%] md:w-[60%] py-4 md:py-8 px-4 md:px-6"
      ]}
      phx-click-away={hide_popup("signin-popup-message")}
    >
      <button class="ml-auto" phx-click={hide_popup("signin-popup-message")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5" />
      </button>
      <div class="mx-auto mb-4">
        <img src={~p"/images/logo.png"} />
      </div>
      <p class="text-sm md:text-base mx-auto mb-6 md:mb-8">
        Take a moment to sign in to continue on ElixirDrops!
      </p>
      <.link
        href={~p"/auth/github"}
        class="font-semibold text-[#eae8fd] text-sm md:text-lg bg-blue_primary hover:opacity-80 w-[55%] md:w-[60%] py-2 md:py-4 mx-auto rounded-lg flex justify-center items-center gap-x-2"
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
          <button
            type="button"
            class="text-[#4f4f4f] text-sm rounded-lg w-[30%] py-2 bg-[#eeeeee] hover:bg-[#eae8fd]"
            phx-click={JS.navigate(~p"/#{@current_user.github_username}")}
          >
            Close editor
          </button>
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
          do: JS.navigate(~p"/drop/new"),
          else: show_popup("signin-popup-message")
      }
    >
      <span><.icon name="hero-plus" /></span>
      <span>Create Post</span>
    </.link>

    <.link
      :if={@live_action == :index}
      id="create-post-btn-mobile"
      phx-hook="CreatePostButtonMobile"
      class={[
        "bg-[#2f19ee] h-10 w-10 rounded-full fixed bottom-4 right-3 z-[10000] md:hidden flex items-center justify-center hover:opacity-80"
      ]}
      phx-click={
        if @current_user,
          do: JS.navigate(~p"/drop/new"),
          else: show_popup("signin-popup-message")
      }
    >
      <.icon name="hero-plus" class="text-[#eae8fd] h-5 w-5" />
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
      <.drop_card_action_default id={@id}>
        <:inner_text>
          Copy link
        </:inner_text>
      </.drop_card_action_default>

      <.link
        navigate={"/drop/#{@id}/edit"}
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
            href={~p"/#{@current_user.github_username}"}
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

  slot :inner_text

  defp drop_card_action_default(assigns) do
    ~H"""
    <div
      id={"card-copy-link-#{@id}"}
      data-clipboard-text={url(~p"/drops/#{@id}")}
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
    |> JS.add_class("shadow-md shadow-[#b2b2b2]", to: ".header")
  end

  @spec show_popup(String.t()) :: Phoenix.LiveView.JS.t()
  def show_popup(pop_up_message_id) do
    %JS{}
    |> JS.remove_class("hidden", to: "##{pop_up_message_id}")
    |> JS.add_class("bg-[#acacac]", to: ".drops-container")
    |> JS.add_class("pointer-events-none ", to: ".drops-container")
    |> JS.add_class("z-[10]", to: ".drops-container")
    |> JS.remove_class("bg-[#f6f6f6]", to: ".drop-card")
    |> JS.add_class("bg-[#a7a7a7]", to: ".drop-card")
    |> JS.remove_class("shadow-[#bebbc2]", to: ".drop-card")
    |> JS.add_class("shadow-[#878589]", to: ".drop-card")
    |> JS.add_class("backdrop-brightness-20 bg-white/30", to: ".drop-form")
    |> JS.add_class("backdrop-brightness-20 bg-white/30", to: ".drop-text-editor")
    |> JS.add_class("backdrop-brightness-20 bg-white/30", to: ".drop-title-input")
    |> JS.add_class("backdrop-brightness-20 bg-white/30", to: ".drop-editor-input")
    |> JS.add_class("backdrop-brightness-20 bg-white/30", to: ".drop-preview-container")
    |> JS.add_class("backdrop-brightness-20 bg-white/30", to: ".action")
  end

  @spec hide_popup(String.t()) :: Phoenix.LiveView.JS.t()
  def hide_popup(pop_up_message_id) do
    %JS{}
    |> JS.add_class("hidden", to: "##{pop_up_message_id}")
    |> JS.remove_class("bg-[#acacac]", to: ".drops-container")
    |> JS.remove_class("pointer-events-none ", to: ".drops-container")
    |> JS.remove_class("z-[10]", to: ".drops-container")
    |> JS.remove_class("bg-[#a7a7a7]", to: ".drop-card")
    |> JS.add_class("bg-[#f6f6f6]", to: ".drop-card")
    |> JS.remove_class("shadow-[#878589]", to: ".drop-card")
    |> JS.add_class("shadow-[#bebbc2]", to: ".drop-card")
    |> JS.remove_class("backdrop-brightness-20 bg-white/30", to: ".drop-form")
    |> JS.remove_class("backdrop-brightness-20 bg-white/30", to: ".drop-text-editor")
    |> JS.remove_class("backdrop-brightness-20 bg-white/30", to: ".drop-title-input")
    |> JS.remove_class("backdrop-brightness-20 bg-white/30", to: ".drop-editor-input")
    |> JS.remove_class("backdrop-brightness-20 bg-white/30", to: ".drop-preview-container")
    |> JS.remove_class("backdrop-brightness-20 bg-white/30", to: ".action")
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
