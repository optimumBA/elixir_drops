defmodule ElixirDrops.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Notifications.Notification
  alias ElixirDrops.Notifications.NotificationsBroadcast
  alias ElixirDrops.Repo

  @type attrs :: map()
  @type changeset :: Ecto.Changeset.t()
  @type comment :: Comment.t()
  @type notification :: Notification.t()
  @type notification_id :: Ecto.UUID.t()
  @type user :: User.t()
  @type user_id :: Ecto.UUID.t()

  @spec subscribe(user_id()) :: :ok
  def subscribe(user_id) do
    NotificationsBroadcast.subscribe(user_id)
  end

  @spec dispatch_notification(notification()) :: :ok
  def dispatch_notification(notification) do
    NotificationsBroadcast.broadcast_notification_creation(notification)
  end

  @spec list_notifications(map(), integer()) :: [notification()]
  def list_notifications(filters, limit \\ 10) do
    filter_query = apply_filters()

    notifications_query()
    |> where(^filter_query.(filters))
    |> where([n], n.read == false)
    |> order_by([n], desc: n.inserted_at)
    |> limit(^limit)
    |> preload(^preload_list())
    |> Repo.all()
  end

  defp notifications_query do
    from notification in Notification, as: :notification
  end

  defp apply_filters do
    fn filters ->
      Enum.reduce(filters, dynamic(true), &apply_filter/2)
    end
  end

  defp apply_filter({:user_id, user_id}, dynamic) do
    dynamic([notification: notification], ^dynamic and notification.recipient_id == ^user_id)
  end

  defp apply_filter({:older_than, notification}, dynamic) do
    dynamic(
      [notification: notification],
      ^dynamic and notification.inserted_at < ^notification.inserted_at
    )
  end

  @doc """
  Counts notifications for a user.

  ## Examples

      iex> count_user_notifications("550e8400-e29b-41d4-a716-446655440000")
      5

  """
  @spec count_user_notifications(user_id) :: non_neg_integer()
  def count_user_notifications(user_id) do
    Notification
    |> where([n], n.recipient_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Creates a notification.

  ## Examples

      iex> create_notification(%User{}, %User{}, %Comment{}, %{type: :comment_on_post})
      {:ok, %Notification{}}

      iex> create_notification(%User{}, %User{}, %Comment{}, %{type: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_notification(user(), user(), comment(), attrs()) ::
          {:ok, notification()} | {:error, changeset()}
  def create_notification(%User{} = actor, %User{} = recipient, %Comment{} = comment, attrs) do
    %Notification{}
    |> create_notification_changeset(actor, recipient, comment, attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a notification.

  ## Examples

      iex> update_notification(%Notification{}, %{type: :reply_to_comment})
      {:ok, %Notification{}}

      iex> update_notification(%Notification{}, %{type: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_notification(notification(), attrs()) ::
          {:ok, notification()} | {:error, changeset()}
  def update_notification(%Notification{} = notification, attrs) do
    notification
    |> Notification.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a notification.

  ## Examples

      iex> delete_notification(notification_id)
      {1, nil}

      iex> delete_notification(notification_id)
      {0, nil}

  """
  @spec delete_notification(notification_id()) :: {integer(), nil}
  def delete_notification(notification_id) do
    Notification
    |> where([n], n.id == ^notification_id)
    |> Repo.delete_all()
  end

  @doc """
  Deletes all notifications for a user.

  ## Examples

      iex> delete_user_notifications("550e8400-e29b-41d4-a716-446655440000")
      {5, nil}

  """
  @spec delete_user_notifications(user_id()) :: {integer(), nil}
  def delete_user_notifications(user_id) do
    Notification
    |> where([n], n.recipient_id == ^user_id)
    |> Repo.delete_all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking notification changes.

  ## Examples

      iex> change_notification(%Notification{})
      %Ecto.Changeset{data: %Notification{}}

  """
  @spec change_notification(notification(), attrs()) :: changeset()
  def change_notification(%Notification{} = notification, attrs \\ %{}) do
    Notification.changeset(notification, attrs)
  end

  defp create_notification_changeset(notification, actor, recipient, comment, attrs) do
    notification
    |> Notification.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:actor, actor)
    |> Ecto.Changeset.put_assoc(:recipient, recipient)
    |> Ecto.Changeset.put_assoc(:comment, comment)
    |> validate_actor_not_recipient(actor, recipient)
  end

  defp validate_actor_not_recipient(changeset, actor, recipient) do
    if actor.id == recipient.id do
      Ecto.Changeset.add_error(changeset, :recipient, "cannot be the same as the actor")
    else
      changeset
    end
  end

  defp preload_list do
    [:actor, :recipient, comment: [:drop]]
  end
end
