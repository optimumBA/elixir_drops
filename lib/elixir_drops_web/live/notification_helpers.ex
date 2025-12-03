defmodule ElixirDropsWeb.NotificationHelpers do
  @moduledoc """
  Notification functions used across liveviews.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [stream: 4]

  alias ElixirDrops.Notifications

  @type socket :: Phoenix.LiveView.Socket.t()

  @spec assign_notifications(socket()) :: socket()
  def assign_notifications(%{assigns: %{current_user: nil}} = socket) do
    socket
    |> stream(:notifications, [], reset: true)
    |> assign(:notification_count, 0)
    |> assign(:notifications_empty?, true)
  end

  def assign_notifications(%{assigns: %{current_user: user}} = socket) do
    notifications = Notifications.list_user_notifications(user.id)

    socket
    |> stream(:notifications, notifications, reset: true)
    |> assign(:notification_count, Notifications.count_user_notifications(user.id))
    |> assign(:notifications_empty?, Enum.empty?(notifications))
  end
end
