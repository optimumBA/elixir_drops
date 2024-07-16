defmodule ElixirDropsWeb.DropsLive do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Accounts
  alias ElixirDrops.Accounts.User
  alias ElixirDropsWeb.SharedComponents

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    {:ok, assign_current_user(socket, session["user_token"])}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <SharedComponents.navbar current_user={@current_user} />
    """
  end

  defp assign_current_user(socket, nil), do: assign(socket, :current_user, nil)

  defp assign_current_user(socket, user_token) do
    case Accounts.get_user_by_session_token(user_token) do
      nil -> assign(socket, :current_user, nil)
      %User{} = user -> assign(socket, :current_user, user)
    end
  end
end
