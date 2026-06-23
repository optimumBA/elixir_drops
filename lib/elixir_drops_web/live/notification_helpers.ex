defmodule ElixirDropsWeb.NotificationHelpers do
  @moduledoc """
  Notification functions used across liveviews.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [stream: 4]

  alias ElixirDrops.Notifications

  @notification_batch_size 10

  @type socket :: Phoenix.LiveView.Socket.t()

  @spec assign_notifications(socket()) :: socket()
  def assign_notifications(%{assigns: %{current_user: nil}} = socket) do
    socket
    |> stream(:notifications, [], reset: true)
    |> assign(:last_notification, nil)
    |> assign(:notification_count, 0)
    |> assign(:notification_filters, %{user_id: nil})
  end

  def assign_notifications(%{assigns: %{current_user: user}} = socket) do
    filters = %{user_id: user.id}
    notifications = Notifications.list_notifications(filters)
    last_notification = List.last(notifications)

    socket
    |> assign(:last_notification, last_notification)
    |> stream(:notifications, notifications, reset: true)
    |> assign(:notification_count, Notifications.count_user_notifications(user.id))
    |> assign(:notification_filters, filters)
  end

  @spec load_more(socket()) :: {:noreply, socket()}
  def load_more(socket)

  def load_more(%{assigns: %{end_of_notifications_timeline?: true}} = socket),
    do: {:noreply, socket}

  def load_more(socket) do
    filters = %{older_than: socket.assigns.last_notification}

    {:noreply,
     socket
     |> maybe_insert_notifications(filters, socket.assigns.last_notification)
     |> Phoenix.LiveView.push_event("load_more_notifications_complete", %{})}
  end

  defp maybe_insert_notifications(socket, _filters, _last_notification, _opts \\ [])

  defp maybe_insert_notifications(socket, _filters, nil, _opts) do
    assign(socket, :end_of_notifications_timeline?, true)
  end

  defp maybe_insert_notifications(socket, filters, _last_notification, opts) do
    notifications =
      filters
      |> Map.merge(socket.assigns.notification_filters)
      |> Notifications.list_notifications()

    last_notification = List.last(notifications)

    socket
    |> Phoenix.LiveView.stream(:notifications, notifications, opts)
    |> assign(
      :end_of_notifications_timeline?,
      Enum.count(notifications) < @notification_batch_size
    )
    |> assign(:last_notification, last_notification)
  end
end
