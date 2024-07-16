defmodule ElixirDropsWeb.DropsLive do
  use ElixirDropsWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h1>Elixir Drops and Stuff</h1>
    <.link href={~p"/auth/github"}> Log In </.link>
    """
  end
end
