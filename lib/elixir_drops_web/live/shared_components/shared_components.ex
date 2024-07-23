defmodule ElixirDropsWeb.SharedComponents do
  @moduledoc false

  use ElixirDropsWeb, :html

  alias ElixirDropsWeb.SharedComponents.Icons

  @type assigns :: map()
  @type rendered :: Phoenix.LiveView.Rendered.t()

  @spec navbar(assigns()) :: rendered()
  def navbar(assigns) do
    ~H"""
    <header class="content-grid border-b-[1px] border-b-[#B2B2B2] py-2 w-full relative">
      <nav class="flex items-center justify-between">
        <div>
          <.link href={~p"/"}>
            <Icons.elixir_drops_icon />
          </.link>
        </div>

        <div>
          <%= if @current_user do %>
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
          <% else %>
            <.link
              href={~p"/auth/github"}
              class="font-semibold text-[#eae8fd] bg-blue_primary px-5 py-2 rounded-md flex gap-x-2"
            >
              <span><Icons.github_icon /></span>
              <span> Sign in with GitHub</span>
            </.link>
          <% end %>
        </div>
      </nav>
    </header>
    """
  end

  defp slide_menu(assigns) do
    ~H"""
    <div
      class="hidden w-[25%] shadow-md shadow-[#c4c1c8] rounded-md pt-10 pb-4 absolute top-[90%] right-[2rem] grid z-[1000] bg-white"
      id="slide-menu"
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
          <.link href={~p"/"} class="flex gap-x-2">
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
end
