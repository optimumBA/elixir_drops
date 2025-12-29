defmodule ElixirDrops.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Notifications.Notification
  alias ElixirDrops.Repo

  @type attrs :: map()
  @type changeset :: Ecto.Changeset.t()
  @type comment :: Comment.t()
  @type notification :: Notification.t()
  @type notification_id :: Ecto.UUID.t()
  @type user :: User.t()
  @type user_id :: Ecto.UUID.t()

  @doc """
   Subscribes to notification events.

  ## Examples

      iex> subscribe("550e8400-e29b-41d4-a716-446655440000")
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

      iex> broadcast(notification)
      :ok

  """
  @spec broadcast(notification()) :: :ok
  def broadcast(notification) do
    Phoenix.PubSub.broadcast(
      ElixirDrops.PubSub,
      "notifications-#{notification.recipient_id}",
      {:new_notification, notification}
    )
  end

  @doc """
  Returns a list of unread notifications filtered by the given filters.

  Notifications are ordered by insertion date in descending order and preloaded
  with actor, recipient, and comment associations.

  ## Examples

      iex> list_notifications(%{user_id: user_id})
      [%Notification{}, ...]

      iex> list_notifications(%{older_than: %Notification{}}, 5)
      [%Notification{}, ...]

      iex> list_notifications(%{user_id: user_id}, 20)
      [%Notification{}, ...]

  """
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

  @doc """
  Counts notifications for a user.

  ## Examples

      iex> count_user_notifications("550e8400-e29b-41d4-a716-446655440000")
      5

  """
  @spec count_user_notifications(user_id) :: non_neg_integer()
  def count_user_notifications(user_id) do
    Notification
    |> where([n], n.recipient_id == ^user_id and n.read == false)
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
  Soft deletes all notifications for a user.

  ## Examples

      iex> mark_all_as_read("550e8400-e29b-41d4-a716-446655440000")
      {5, nil}

  """
  @spec mark_all_as_read(user_id()) :: {non_neg_integer(), nil}
  def mark_all_as_read(user_id) do
    Notification
    |> where([n], n.recipient_id == ^user_id)
    |> Repo.update_all(set: [read: true])
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
