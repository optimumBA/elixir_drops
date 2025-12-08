defmodule ElixirDrops.NotificationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ElixirDrops.Notifications` context.
  """

  import ElixirDrops.PaginationHelpers

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Notifications
  alias ElixirDrops.Notifications.Notification

  @type comment :: Comment.t()
  @type notification :: Notification.t()
  @type user :: User.t()

  @doc """
  Generate a notification.
  """
  @spec notification_fixture(user(), user(), comment(), map()) :: notification()
  def notification_fixture(actor, recipient, comment, attrs \\ %{}) do
    notification_attrs =
      Enum.into(attrs, %{
        type: :comment_on_post,
        read: false
      })

    {:ok, notification} =
      Notifications.create_notification(actor, recipient, comment, notification_attrs)

    notification
  end

  @doc """
  Creates multiple notifications.
  """
  @spec create_multiple_notifications(user(), user(), comment(), integer()) ::
          list(notification())
  def create_multiple_notifications(actor, recipient, comment, number_of_notifications) do
    for n <- 1..number_of_notifications do
      offset_time = 120 * n

      notification =
        notification_fixture(actor, recipient, comment, %{
          type: :comment_on_post,
          read: false
        })

      update_inserted_at(
        notification,
        offset_time
      )
    end
  end
end
