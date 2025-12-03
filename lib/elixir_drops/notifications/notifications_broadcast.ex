defmodule ElixirDrops.Notifications.NotificationsBroadcast do
  @moduledoc """
  Broadcasts notifications to user LiveViews.
  """

  alias ElixirDrops.Notifications.Notification

  @type notification :: Notification.t()
  @type user_id :: Ecto.UUID.t()

  @doc """
  Subscribes to notification events.

  ## Examples

    iex> subscribe("075fd22d-5b99-4e38-bf16-c6fcecd38276")
    :ok

  """
  @spec subscribe(user_id()) :: :ok
  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(ElixirDrops.PubSub, "notifications-#{user_id}")
  end

  @doc """
  Broadcasts a message indicating that a new comment has been created.

  ## Parameters

    - `notification`: The notification data to be broadcast.

  ## Examples

      iex> broadcast_notification_creation(notification)
      :ok

  """
  @spec broadcast_notification_creation(notification()) :: :ok
  def broadcast_notification_creation(notification) do
    Phoenix.PubSub.broadcast(
      ElixirDrops.PubSub,
      "notifications-#{notification.recipient_id}",
      :new_notification
    )
  end
end
