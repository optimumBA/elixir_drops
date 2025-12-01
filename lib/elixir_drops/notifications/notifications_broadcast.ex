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

  The message is broadcast on the `@topic` using Phoenix PubSub. Other processes that subscribe to this topic will receive the broadcast message.

  ## Parameters

    - `notification`: The notification data to be broadcast, typically a map or struct representing the newly created notification.

  ## Examples

      iex> broadcast_notification_creation(%{
      ...>   id: 1,
      ...>   title: "New Drop",
      ...>   body: "This is a new drop.",
      ...>   user_id: 1,
      ...>   short_id: "abc123"
      ...> })
      :ok

  """
  @spec broadcast_notification_creation(notification()) :: :ok
  def broadcast_notification_creation(notification) do
    Phoenix.PubSub.broadcast(
      ElixirDrops.PubSub,
      "notifications-#{notification.recipient_id}",
      {
        :notification,
        notification
      }
    )
  end
end
