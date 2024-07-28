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
    <header class="content-grid border-b-[1px] border-b-[#B2B2B2] py-2 w-full relative">
      <nav class="flex items-center justify-between">
        <div>
          <.link href={~p"/"}>
            <Icons.elixir_drops_logo />
          </.link>
        </div>

        <div>
          <%= if @current_user do %>
            <div class="flex items-center gap-x-4">
              <.create_post_button current_user={@current_user} />
              <div class="flex items-center gap-x-3">
                <img
                  src={@current_user.avatar}
                  alt={@current_user.github_username}
                  class="w-10 h-10 rounded-full"
                />
                <p><%= @current_user.github_username %></p>
                <button phx-click={JS.toggle_class("hidden", to: "#slide-menu")}>
                  <Icons.chevron_down />
                </button>
                <.slide_menu current_user={@current_user} />
              </div>
            </div>
          <% else %>
            <div class="flex items-center gap-x-4">
              <.create_post_button current_user={@current_user} />
              <.link
                href={~p"/auth/github"}
                class="font-semibold text-[#eae8fd] text-sm bg-blue_primary hover:opacity-80 px-5 py-2 rounded-lg flex items-center gap-x-2"
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
  attr :timezone_offset, :integer, required: true
  attr :title, :string, required: true

  @spec drop_card(assigns()) :: rendered()
  def drop_card(assigns) do
    ~H"""
    <div class="drop-card bg-[#f6f6f6] px-6 py-8 rounded-lg shadow-md shadow-[#bebbc2] relative">
      <div>
        <div class="flex justify-between">
          <div class="flex gap-2 items-center">
            <img src={@avatar} alt={@github_username} class="rounded-full h-10 w-10 object-cover" />
            <p><%= @github_username %></p>
            <p class="text-[#868686] text-xs before:content-['•'] before:block] before:mr-[0.05rem]">
              Created <%= DateTimeHelper.convert_to_relative_time(@created_at, @timezone_offset) %>
            </p>
          </div>
          <div
            id={"card-copy-link-#{@id}"}
            data-clipboard-text={url(~p"/drops/#{@id}")}
            data-drop-id={@id}
            phx-hook="CopyToClipboard"
            class="text-[#797979] hover:text-[#5947F1]"
          >
            <Icons.link_icon />
          </div>
        </div>

        <h3 class="text-lg font-[500] mt-2"><%= @title %></h3>
      </div>

      <.copy_confirm_message
        class="absolute top-[50%] left-[50%] translate-x-[-50%] translate-y-[-50%]"
        id={@id}
      />
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
    <div class="w-[93%] md:w-[96%] max-w-md md:max-w-xl lg:max-w-2xl mx-auto leading-[1.5] relative">
      <h1 class="font-[500] text-4xl"><%= @title %></h1>
      <div class="flex gap-x-3 items-center border-b-[1px] border-b-[#b2b2b2] py-5">
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
        data-drop-id={@id}
        phx-hook="CopyToClipboard"
        class="mt-4 text-sm text-[#4f4f4f] hover:text-[#5947F1] border-y-[1px] border-y-[#dddddd] flex items-center justify-end gap-x-2 py-3 cursor-pointer"
      >
        <span><Icons.link_icon /></span>
        <span>Copy link</span>
      </p>

      <.copy_confirm_message class="absolute bottom-0 right-0" id={@id} />
    </div>
    """
  end

  @spec welcome_message(assigns()) :: rendered()
  def welcome_message(assigns) do
    ~H"""
    <div
      class={[
        "text-[#EAE8FD] text-sm bg-gradient-to-r from-[#4c3ddb] via-[#6159be] to-[#818494] px-10 py-3 grid full-width__no-columns",
        @show_user_drops? && "hidden"
      ]}
      id="welcome-message"
    >
      <button class="ml-auto" phx-click={JS.hide(to: "#welcome-message")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5" />
      </button>

      <h2 class="font-[500] text-[1.15rem] tracking-wide mb-3">Welcome to ElixirDrops!</h2>

      <p>
        Hello there and welcome to the ultimate hub for the Elixir community!
        Whether you're a seasoned developer or just starting your journey, ElixirDrops is the perfect place to discover, share, and discuss the best tips and tricks for mastering Elixir.
        Sign in to explore, learn and become a contributor on this platform.
      </p>
    </div>
    """
  end

  @spec signin_popup_message(assigns()) :: rendered()
  def signin_popup_message(assigns) do
    ~H"""
    <div
      id="signin-popup-message"
      class="hidden bg-white absolute top-[50%] left-[50%] translate-x-[-50%] translate-y-[-50%] py-8 px-6 rounded-lg w-[50%] shadow-md shadow-[#b2b2b2] z-[10000] grid"
      phx-click-away={hide_popup("signin-popup-message")}
    >
      <button class="ml-auto" phx-click={hide_popup("signin-popup-message")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5" />
      </button>
      <div class="mx-auto mb-4">
        <img src={~p"/images/logo.png"} />
      </div>
      <p class="mx-auto mb-8">Take a moment to sign in to continue on ElixirDrops!</p>
      <.link
        href={~p"/auth/github"}
        class="font-semibold text-[#eae8fd] text-lg bg-blue_primary hover:opacity-80 w-[60%] py-4 mx-auto rounded-lg flex justify-center items-center gap-x-2"
      >
        <span><Icons.github_icon /></span>
        <span> Sign in with GitHub</span>
      </.link>
    </div>
    """
  end

  defp copy_confirm_message(assigns) do
    ~H"""
    <p
      id={"copy-confirm-message-#{@id}"}
      class={[
        "hidden text-[#eae8fd] text-sm bg-[#9666d9] rounded-md px-6 py-4 flex items-center gap-x-1 z-[1000]",
        @class
      ]}
    >
      <span><Icons.check_icon /></span>
      <span>Link copied to clipboard. </span>
    </p>
    """
  end

  defp create_post_button(assigns) do
    ~H"""
    <button
      class={[
        "text-sm tracking-wide px-6 py-2 rounded-lg flex items-center gap-x-2",
        @current_user && "text-[#eae8fd] bg-blue_primary hover:opacity-80",
        !@current_user && "text-blue_primary border-blue_primary border-2 hover:bg-[#eae8fd]"
      ]}
      phx-click={
        if @current_user,
          do: JS.navigate(~p"/drop/new"),
          else: show_popup("signin-popup-message")
      }
    >
      <span><.icon name="hero-plus" /></span>
      <span>Create Post</span>
    </button>
    """
  end

  defp slide_menu(assigns) do
    ~H"""
    <div
      class="hidden w-[25%] shadow-md shadow-[#c4c1c8] rounded-md pt-10 pb-4 absolute top-[90%] right-[2rem] grid z-[1000] bg-white"
      id="slide-menu"
      phx-click-away={JS.toggle_class("hidden", to: "#slide-menu")}
    >
      <div class="mx-auto">
        <img
          src={@current_user.avatar}
          alt={@current_user.github_username}
          class="w-16 h-16 rounded-full"
        />
      </div>
      <p class="text-[1.2rem] mx-auto mt-1"><%= @current_user.github_username %></p>

      <ul class="mt-10 grid gap-y-6">
        <li class="px-5">
          <.link navigate={~p"/#{@current_user.github_username}"} class="flex gap-x-2">
            <span><Icons.drops_icon /></span>
            <span> My posts </span>
          </.link>
        </li>
        <li class="nav-list-border full-bleed"></li>
        <li class="px-5">
          <.link href={~p"/auth/logout"} class="flex gap-x-2 ">
            <span><Icons.sign_out_icon /></span>
            <span>Sign out</span>
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  defp show_popup(pop_up_message_id) do
    %JS{}
    |> JS.remove_class("hidden", to: "##{pop_up_message_id}")
    |> JS.add_class("bg-[#acacac]", to: ".drops-container")
    |> JS.add_class("pointer-events-none ", to: ".drops-container")
    |> JS.add_class("z-[10]", to: ".drops-container")
    |> JS.add_class("bg-[#a7a7a7]", to: ".drop-card")
    |> JS.add_class("shadow-[#878589]", to: ".drop-card")
  end

  defp hide_popup(pop_up_message_id) do
    %JS{}
    |> JS.add_class("hidden", to: "##{pop_up_message_id}")
    |> JS.remove_class("bg-[#acacac]", to: ".drops-container")
    |> JS.remove_class("pointer-events-none ", to: ".drops-container")
    |> JS.remove_class("z-[10]", to: ".drops-container")
    |> JS.remove_class("bg-[#a7a7a7]", to: ".drop-card")
    |> JS.remove_class("shadow-[#878589]", to: ".drop-card")
  end

  defp to_html(markdown) do
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
