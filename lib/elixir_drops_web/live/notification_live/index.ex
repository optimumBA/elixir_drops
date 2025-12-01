defmodule ElixirDropsWeb.NotificationLive.Index do
  use ElixirDropsWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # user_id = socket.assigns.current_user.id

    {:ok, socket, layout: false}
  end
end
