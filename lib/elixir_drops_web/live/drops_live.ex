defmodule ElixirDropsWeb.DropsLive do
  use ElixirDropsWeb, :live_view

  alias ElixirDropsWeb.SharedComponents

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <SharedComponents.navbar current_user={@current_user} />
    """
  end
end
