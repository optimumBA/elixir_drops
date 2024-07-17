defmodule ElixirDropsWeb.SharedComponents do
  @moduledoc false

  use ElixirDropsWeb, :html

  alias ElixirDropsWeb.SharedComponents.Icons

  @type assigns :: map()
  @type rendered :: Phoenix.LiveView.Rendered.t()

  @spec navbar(assigns()) :: rendered()
  def navbar(assigns) do
    ~H"""
    <header class="content-grid border-b-2 border-b-[#B2B2B2] py-2 w-full">
      <nav class="flex items-center justify-between">
        <div>
          <.link href={~p"/"}>
            <Icons.elixir_drops_icon />
          </.link>
        </div>

        <div>
          <%= if @current_user do %>
            <div class="flex items-center gap-x-3">
              <.user_avatar current_user={@current_user} />
              <p><%= @current_user.github_username %></p>
              <button>
                <Icons.chevron_down />
              </button>
            </div>
          <% else %>
            <.link
              href={~p"/auth/github"}
              class="font-semibold text-[#eae8fd] bg-blue_primary px-5 py-2 rounded-md flex gap-x-2"
            >
              <span><Icons.github_icon /></span>
              <span> Log in with GitHub</span>
            </.link>
          <% end %>
        </div>
      </nav>
    </header>
    """
  end

  defp user_avatar(assigns) do
    ~H"""
    <%= if @current_user.avatar do %>
      <img
        src={@current_user.avatar}
        alt={@current_user.github_username}
        class="w-10 h-10 rounded-full"
      />
    <% else %>
      <p class="font-semibold text-[#eae8fd] bg-blue_primary text-xl rounded-full w-10 h-10 flex items-center justify-center">
        <%= upcase_first(@current_user.github_username) %>
      </p>
    <% end %>
    """
  end

  defp upcase_first(<<first::utf8, _rest::binary>>), do: String.upcase(<<first::utf8>>)
end
