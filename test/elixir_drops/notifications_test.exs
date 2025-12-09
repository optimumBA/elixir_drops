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
    setup [:create_notification_setup]

    test "returns a list of unread notifications for a user", %{
      notification: notification,
      recipient: recipient
    } do
      notifications = Notifications.list_notifications(%{user_id: recipient.id})
      assert notification.id in Enum.map(notifications, & &1.id)
      assert Enum.all?(notifications, fn n -> n.read == false end)
    end

    test "preloads actor, recipient, and comment associations", %{recipient: recipient} do
      [notification] = Notifications.list_notifications(%{user_id: recipient.id})

      assert Ecto.assoc_loaded?(notification.actor)
      assert Ecto.assoc_loaded?(notification.recipient)
      assert Ecto.assoc_loaded?(notification.comment)
      assert Ecto.assoc_loaded?(notification.comment.drop)
    end

    test "returns empty list when a user has no notifications" do
      non_existing_user_id = Ecto.UUID.generate()
      assert [] = Notifications.list_notifications(%{user_id: non_existing_user_id})
    end

    test "excludes read notifications", %{actor: actor, comment: comment} do
      recipient = user_fixture()

      read_notification = notification_fixture(actor, recipient, comment, %{read: true})
      unread_notification = notification_fixture(actor, recipient, comment, %{read: false})

      notifications = Notifications.list_notifications(%{user_id: recipient.id})
      assert length(notifications) == 1
      notification_ids = Enum.map(notifications, & &1.id)
      assert unread_notification.id in notification_ids
      refute read_notification.id in notification_ids
    end

    test "orders notifications by inserted_at (newest first)", %{actor: actor, comment: comment} do
      recipient = user_fixture()
      create_multiple_notifications(actor, recipient, comment, 3)

      [notification_1, notification_2, notification_3] =
        Notifications.list_notifications(%{user_id: recipient.id})

      assert NaiveDateTime.compare(notification_1.inserted_at, notification_2.inserted_at) == :gt
      assert NaiveDateTime.compare(notification_2.inserted_at, notification_3.inserted_at) == :gt
    end

    test "gets notifications older than another notification", %{actor: actor, comment: comment} do
      recipient = user_fixture()
      create_multiple_notifications(actor, recipient, comment, 3)

      [notification_1] =
        Notifications.list_notifications(%{user_id: recipient.id}, 1)

      [notification_2, notification_3] =
        Notifications.list_notifications(%{user_id: recipient.id, older_than: notification_1})

      assert NaiveDateTime.compare(notification_1.inserted_at, notification_2.inserted_at) == :gt
      assert NaiveDateTime.compare(notification_1.inserted_at, notification_3.inserted_at) == :gt
    end
  end

  describe "count_user_notifications/1" do
    setup [:create_notification_setup]

    test "returns the count of unread notifications for a user", %{actor: actor, comment: comment} do
      recipient = user_fixture()
      create_multiple_notifications(actor, recipient, comment, 3)
      assert Notifications.count_user_notifications(recipient.id) == 3
    end

    test "returns 0 when a user has no notifications" do
      non_existing_user_id = Ecto.UUID.generate()
      assert Notifications.count_user_notifications(non_existing_user_id) == 0
    end

    test "does not count read notifications", %{actor: actor, comment: comment} do
      recipient = user_fixture()
      notification_fixture(actor, recipient, comment, %{read: true})
      notification_fixture(actor, recipient, comment, %{read: false})

      assert Notifications.count_user_notifications(recipient.id) == 1
    end
  end

  describe "create_notification/4" do
    setup [:create_notification_setup]

    test "creates a notification given valid data", %{
      actor: actor,
      comment: comment,
      recipient: recipient
    } do
      attrs = %{type: :comment_on_post, read: false}

      assert {:ok, %Notification{} = notification} =
               Notifications.create_notification(actor, recipient, comment, attrs)

      assert notification.type == :comment_on_post
      assert notification.read == false
      assert notification.actor_id == actor.id
      assert notification.recipient_id == recipient.id
      assert notification.comment_id == comment.id
    end

    test "creates a reply_to_comment notification", %{
      actor: actor,
      drop: drop,
      recipient: recipient
    } do
      comment = comment_fixture(drop, recipient, nil)
      reply_comment = comment_fixture(drop, actor, comment)
      attrs = %{type: :reply_to_comment, read: false}

      assert {:ok, %Notification{} = notification} =
               Notifications.create_notification(actor, recipient, reply_comment, attrs)

      assert notification.type == :reply_to_comment
      assert notification.read == false
      assert notification.actor_id == actor.id
      assert notification.recipient_id == recipient.id
      assert notification.comment_id == reply_comment.id
    end

    test "returns an error changeset if actor is the same as recipient", %{
      actor: actor,
      comment: comment
    } do
      attrs = %{type: :comment_on_post}

      assert {:error, %Ecto.Changeset{} = changeset} =
               Notifications.create_notification(actor, actor, comment, attrs)

      assert %{recipient: ["cannot be the same as the actor"]} = errors_on(changeset)
    end

    test "returns an error changeset if type is invalid", %{
      actor: actor,
      comment: comment,
      recipient: recipient
    } do
      attrs = %{type: nil, read: false}

      assert {:error, %Ecto.Changeset{}} =
               Notifications.create_notification(actor, recipient, comment, attrs)
    end
  end

  describe "soft_delete_user_notifications/1" do
    setup [:create_notification_setup]

    test "marks all notifications for a user as read", %{
      actor: actor,
      comment: comment
    } do
      recipient = user_fixture()
      create_multiple_notifications(actor, recipient, comment, 3)
      assert Notifications.count_user_notifications(recipient.id) == 3

      {count, nil} = Notifications.soft_delete_user_notifications(recipient.id)

      assert count == 3
      assert Notifications.count_user_notifications(recipient.id) == 0
    end

    test "returns {0, nil} when user has no notifications" do
      non_existing_user_id = Ecto.UUID.generate()

      assert {0, nil} = Notifications.soft_delete_user_notifications(non_existing_user_id)
    end
  end

  describe "subscribe/1" do
    test "returns :ok and subscribes caller to the user's notifications topic" do
      user_id = Ecto.UUID.generate()

      assert :ok == Notifications.subscribe(user_id)
    end
  end

  describe "dispatch_notification/1" do
    setup [:create_notification_setup]

    test "broadcasts a notification creation event", %{
      notification: notification,
      recipient: recipient
    } do
      :ok = Notifications.subscribe(recipient.id)
      :ok = Notifications.dispatch_notification(notification)

      assert_receive {:new_notification, ^notification}
    end
  end
end
