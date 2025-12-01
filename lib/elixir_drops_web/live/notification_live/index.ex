defmodule ElixirDropsWeb.NotificationLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Notifications

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    notifications = Notifications.list_user_notifications(user_id)

    {:ok, stream(socket, :notifications, notifications, reset: true), layout: false}
  end
end
