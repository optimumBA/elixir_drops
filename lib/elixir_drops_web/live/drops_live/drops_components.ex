defmodule ElixirDropsWeb.DropsLive.DropsComponents do
  @moduledoc false

  use ElixirDropsWeb, :html

  alias ElixirDropsWeb.SharedComponents.Icons

  @type assigns() :: map()
  @type rendered() :: Phoenix.LiveView.Rendered.t()

  attr :avatar, :string, required: true
  attr :created_at, :string, required: true
  attr :github_username, :string, required: true
  attr :timezone_offset, :integer, required: true
  attr :title, :string, required: true

  #TODO: Figure out sharing(how the links will look like, how pasted links should like)
  @spec drop_card(assigns()) :: rendered()
  def drop_card(assigns) do
    ~H"""
    <div class="bg-[#f6f6f6] px-6 py-8 rounded-lg shadow-md shadow-[#bebbc2]">
      <div class="flex justify-between">
        <div class="flex gap-2 items-center">
          <img src={@avatar} alt={@github_username} class="rounded-full h-10 w-10 object-cover" />
          <p><%= @github_username %></p>
          <p class="text-[#868686] text-xs before:content-['•'] before:block] before:mr-[0.05rem]">
            Created <%= convert_time(@created_at, @timezone_offset) %>
          </p>
        </div>
        <Icons.link_icon />
      </div>

      <h3 class="text-lg font-[500] mt-2"><%= @title %></h3>
    </div>
    """
  end

  attr :avatar, :string, required: true
  attr :body, :string, required: true
  attr :created_at, :string, required: true
  attr :github_username, :string, required: true
  attr :timezone_offset, :integer, required: true
  attr :title, :string, required: true

  @spec drop(assigns()) :: rendered()
  def drop(assigns) do
    ~H"""
    <div class="w-[93%] md:w-[96%] max-w-md md:max-w-xl lg:max-w-2xl mx-auto leading-[1.5]">
      <h1 class="font-[500] text-4xl"><%= @title %></h1>
      <div class="flex gap-x-3 items-center border-b-[1px] border-b-[#b2b2b2] py-5">
        <img src={@avatar} alt={@github_username} class="rounded-full h-12 w-12 object-cover" />

        <div>
          <p class="mb-1"><%= @github_username %></p>
          <p class="text-[#696969] text-xs">
            Created <%= convert_time(@created_at, @timezone_offset) %>
          </p>
        </div>
      </div>

      <div class="leading-[1.6] grid w-full py-3 drop-body" id="drop-body" phx-hook="DropBodyContainer">
        <%= to_html(@body) %>
      </div>

      <p class="mt-4 text-sm text-[#4f4f4f] border-y-[1px] border-y-[#dddddd] flex items-center justify-end gap-x-2 py-3">
        <span><Icons.link_icon /></span>
        <span>Copy link</span>
      </p>
    </div>
    """
  end

  # TODO: bg-gradient slightly different from design
  @spec welcome_message(assigns()) :: rendered()
  def welcome_message(assigns) do
    ~H"""
    <div
      class="text-[#EAE8FD] text-sm bg-gradient-to-r from-[#4c3ddb] via-[#6159be] to-[#7d7f99] px-10 py-3 grid full-width__no-columns"
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

  defp convert_time(time, timezone_offset) do
    {:ok, created_at_time} =
      time
      |> NaiveDateTime.add(-1 * timezone_offset, :second)
      |> Timex.format("{relative}", :relative)

    created_at_time
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
