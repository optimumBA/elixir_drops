defmodule ElixirDrops.NotificationsTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.CommentsFixtures
  import ElixirDrops.DropsFixtures
  import ElixirDrops.NotificationsFixtures

  alias ElixirDrops.Notifications
  alias ElixirDrops.Notifications.Notification

  defp create_notification_setup(_attrs) do
    actor = user_fixture(%{name: "actor_name"})
    recipient = user_fixture(%{name: "recipient_name"})
    drop = drop_fixture(recipient)
    comment = comment_fixture(drop, actor, nil)
    notification = notification_fixture(actor, recipient, comment)

    %{
      actor: actor,
      comment: comment,
      drop: drop,
      notification: notification,
      recipient: recipient
    }
  end

  describe "list_notifications/2" do
    test "returns a list of unread notifications for a user" do
      %{notification: notification, recipient: recipient} = create_notification_setup(%{})

      notifications = Notifications.list_notifications(%{user_id: recipient.id})

      assert notification.id in Enum.map(notifications, & &1.id)
      assert Enum.all?(notifications, fn n -> n.read == false end)
    end

    test "preloads actor, recipient, and comment associations" do
      %{recipient: recipient} = create_notification_setup(%{})
      [notification] = Notifications.list_notifications(%{user_id: recipient.id})

      assert Ecto.assoc_loaded?(notification.actor)
      assert Ecto.assoc_loaded?(notification.recipient)
      assert Ecto.assoc_loaded?(notification.comment)
      assert Ecto.assoc_loaded?(notification.comment.drop)
    end

    test "returns empty list when a user has no notifications" do
      create_notification_setup(%{})
      non_existing_user_id = Ecto.UUID.generate()

      assert [] = Notifications.list_notifications(%{user_id: non_existing_user_id})
    end

    test "excludes read notifications" do
      actor = user_fixture()
      recipient = user_fixture()
      drop = drop_fixture(recipient)
      comment = comment_fixture(drop, actor, nil)

      # Create a read notification
      _read_notification = notification_fixture(actor, recipient, comment, %{read: true})

      # Create an unread notification
      unread_notification = notification_fixture(actor, recipient, comment, %{read: false})

      notifications = Notifications.list_notifications(%{user_id: recipient.id})
      assert length(notifications) == 1
      assert unread_notification not in Enum.map(notifications, & &1.id)
    end

    test "orders notifications by inserted_at (newest first)" do
      actor = user_fixture()
      recipient = user_fixture()
      drop = drop_fixture(recipient)
      comment = comment_fixture(drop, actor, nil)
      create_multiple_notifications(actor, recipient, comment, 3)

      [notification_1, notification_2, notification_3] =
        Notifications.list_notifications(%{user_id: recipient.id})

      assert NaiveDateTime.compare(notification_1.inserted_at, notification_2.inserted_at) == :gt
      assert NaiveDateTime.compare(notification_2.inserted_at, notification_3.inserted_at) == :gt
    end
  end

  describe "count_user_notifications/1" do
    test "returns the count of unread notifications for a user" do
      %{actor: actor, recipient: recipient, comment: comment} = create_notification_setup(%{})
      create_multiple_notifications(actor, recipient, comment, 3)
      assert Notifications.count_user_notifications(recipient.id) == 4
    end

    test "returns 0 when a user has no notifications" do
      create_notification_setup(%{})
      non_existing_user_id = Ecto.UUID.generate()
      assert Notifications.count_user_notifications(non_existing_user_id) == 0
    end

    test "does not count read notifications" do
      actor = user_fixture()

      recipient =
        user_fixture(%{
          name: "recipient_name"
        })

      drop = drop_fixture(recipient)
      comment = comment_fixture(drop, actor, nil)

      notification_fixture(actor, recipient, comment, %{read: true})
      notification_fixture(actor, recipient, comment, %{read: false})

      assert Notifications.count_user_notifications(recipient.id) == 1
    end
  end

  describe "create_notification/4" do
    test "creates a notification given valid data" do
      actor = user_fixture()

      recipient =
        user_fixture(%{
          name: "recipient_name"
        })

      drop = drop_fixture(recipient)
      comment = comment_fixture(drop, actor, nil)

      attrs = %{type: :comment_on_post}

      assert {:ok, %Notification{} = notification} =
               Notifications.create_notification(actor, recipient, comment, attrs)

      assert notification.type == :comment_on_post
      assert notification.read == false
      assert notification.actor_id == actor.id
      assert notification.recipient_id == recipient.id
      assert notification.comment_id == comment.id
    end

    test "returns an error changeset if actor is the same as recipient" do
      actor = user_fixture()
      drop = drop_fixture(actor)
      comment = comment_fixture(drop, actor, nil)

      attrs = %{type: :comment_on_post}

      assert {:error, %Ecto.Changeset{} = changeset} =
               Notifications.create_notification(actor, actor, comment, attrs)

      assert %{recipient: ["cannot be the same as the actor"]} = errors_on(changeset)
    end

    test "returns an error changeset if type is invalid" do
      actor = user_fixture()

      recipient =
        user_fixture(%{
          avatar: "https://avatars.githubusercontent.com/u/44444?v=4",
          email: "recipient6@mail.com",
          github_id: 44_444,
          github_username: "recipient6_username",
          name: "recipient6_name"
        })

      drop = drop_fixture(recipient)
      comment = comment_fixture(drop, actor, nil)

      attrs = %{type: nil, read: false}

      assert {:error, %Ecto.Changeset{}} =
               Notifications.create_notification(actor, recipient, comment, attrs)
    end
  end

  describe "soft_delete_user_notifications/1" do
    test "marks all notifications for a user as read" do
      %{actor: actor, recipient: recipient, comment: comment} = create_notification_setup(%{})

      # Create additional unread notifications
      create_multiple_notifications(actor, recipient, comment, 3)

      # Verify we have unread notifications
      assert Notifications.count_user_notifications(recipient.id) == 4

      # Soft delete (mark as read)
      {count, nil} = Notifications.soft_delete_user_notifications(recipient.id)

      assert count == 4
      assert Notifications.count_user_notifications(recipient.id) == 0
    end

    test "returns {0, nil} when user has no notifications" do
      non_existing_user_id = Ecto.UUID.generate()

      assert {0, nil} = Notifications.soft_delete_user_notifications(non_existing_user_id)
    end

    test "only affects the specified user's notifications" do
      %{actor: actor, recipient: recipient, comment: comment} = create_notification_setup(%{})

      # Create another recipient
      recipient_2 =
        user_fixture(%{
          avatar: "https://avatars.githubusercontent.com/u/33333?v=4",
          email: "recipient7@mail.com",
          github_id: 33_333,
          github_username: "recipient7_username",
          name: "recipient7_name"
        })

      drop_2 = drop_fixture(recipient_2)
      comment_2 = comment_fixture(drop_2, actor, nil)

      # Create notifications for recipient_2
      create_multiple_notifications(actor, recipient_2, comment_2, 2)

      # Create notifications for original recipient
      create_multiple_notifications(actor, recipient, comment, 2)

      # Soft delete only recipient's notifications
      Notifications.soft_delete_user_notifications(recipient.id)

      # recipient should have 0 unread notifications
      assert Notifications.count_user_notifications(recipient.id) == 0

      # recipient_2 should still have their notifications
      assert Notifications.count_user_notifications(recipient_2.id) == 2
    end
  end

  describe "subscribe/1" do
    test "returns :ok and subscribes caller to the user's notifications topic" do
      user_id = Ecto.UUID.generate()

      assert :ok == Notifications.subscribe(user_id)
    end
  end

  describe "dispatch_notification/1" do
    test "broadcasts a notification creation event" do
      %{notification: notification, recipient: recipient} = create_notification_setup(%{})

      # Subscribe to the recipient's notifications channel
      :ok = Notifications.subscribe(recipient.id)

      # Dispatch the notification
      :ok = Notifications.dispatch_notification(notification)

      # Assert we receive the broadcast
      assert_receive {:new_notification, ^notification}
    end
  end
end
