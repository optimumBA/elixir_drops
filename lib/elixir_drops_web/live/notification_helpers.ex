defmodule ElixirDropsWeb.NotificationHelpers do
  @moduledoc """
  Notification functions used across liveviews.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [stream: 4]

  alias ElixirDrops.Notifications
  alias ElixirDrops.Notifications.Notification

  @notification_batch_size 10

  @type filters :: map()
  @type notification :: Notification.t()
  @type opts :: Keyword.t()
  @type socket :: Phoenix.LiveView.Socket.t()

  @spec assign_notifications(socket()) :: socket()
  def assign_notifications(%{assigns: %{current_user: nil}} = socket) do
    socket
    |> stream(:notifications, [], reset: true)
    |> assign(:notification_count, 0)
    |> assign(:notifications_empty?, true)
  end

  def assign_notifications(%{assigns: %{current_user: user}} = socket) do
    filters = %{user_id: user.id}
    notifications = Notifications.list_notifications(filters)
    last_notification = List.last(notifications)

    socket
    |> stream(:notifications, notifications, reset: true)
    |> assign(:last_notification, last_notification)
    |> assign(:notification_count, Notifications.count_user_notifications(user.id))
    |> assign(:notifications_empty?, Enum.empty?(notifications))
    |> assign(:notification_filters, filters)
  end

  @spec load_more(socket(), pos_integer()) :: {:noreply, socket()}
  def load_more(socket, batch_size \\ 10)

  def load_more(%{assigns: %{end_of_notifications_timeline?: true}} = socket, _batch_size),
    do: {:noreply, socket}

  def load_more(socket, _batch_size) do
    filters = %{older_than: socket.assigns.last_notification}

    {:noreply,
     socket
     |> assign(:notifications_page, socket.assigns.notifications_page + 1)
     |> maybe_insert_notifications(filters, socket.assigns.last_notification)}
  end

  @spec maybe_insert_notifications(socket(), filters(), notification(), opts()) :: socket()
  def maybe_insert_notifications(socket, _filters, _first_or_last_notification, _opts \\ [])

  def maybe_insert_notifications(socket, _filters, nil, _opts) do
    assign(socket, :end_of_notifications_timeline?, true)
  end

  def maybe_insert_notifications(socket, filters, _first_or_last_notification, opts) do
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
