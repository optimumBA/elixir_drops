defmodule ElixirDrops.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Notifications.Notification
  alias ElixirDrops.Notifications.NotificationsBroadcast
  alias ElixirDrops.Repo

  @type attrs :: map()
  @type changeset :: Ecto.Changeset.t()
  @type drop :: Drop.t()
  @type notification :: Notification.t()
  @type notification_id :: Ecto.UUID.t()
  @type user :: User.t()
  @type user_id :: Ecto.UUID.t()

  @doc """
  Lists notifications for a user with pagination.

  ## Examples

      iex> list_user_notifications("550e8400-e29b-41d4-a716-446655440000")
      [%Notification{}, ...]

      iex> list_user_notifications("550e8400-e29b-41d4-a716-446655440000", limit: 5, offset: 10)
      [%Notification{}, ...]

  """

  @spec subscribe(user_id()) :: :ok
  def subscribe(user_id) do
    NotificationsBroadcast.subscribe(user_id)
  end

  @spec list_user_notifications(user_id, keyword()) :: [notification()]
  def list_user_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)

    Notification
    |> where([n], n.recipient_id == ^user_id)
    |> order_by([n], desc: n.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload(^preload_list())
    |> Repo.all()
  end

  @doc """
  Gets a single notification.

  Raises `Ecto.NoResultsError` if the notification does not exist.

  ## Examples

      iex> get_notification!("550e8400-e29b-41d4-a716-446655440000")
      %Notification{}

      iex> get_notification!("non_existent_id")
      ** (Ecto.NoResultsError)

  """
  @spec get_notification!(notification_id) :: notification()
  def get_notification!(id) do
    Notification
    |> Repo.get!(id)
    |> Repo.preload(preload_list())
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

      iex> create_notification(%User{}, %User{}, %Drop{}, %{type: :comment_on_post})
      {:ok, %Notification{}}

      iex> create_notification(%User{}, %User{}, %Drop{}, %{type: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_notification(user(), user(), drop(), attrs()) ::
          {:ok, notification()} | {:error, changeset()}
  def create_notification(%User{} = actor, %User{} = recipient, %Drop{} = drop, attrs) do
    %Notification{}
    |> create_notification_changeset(actor, recipient, drop, attrs)
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

  defp create_notification_changeset(notification, actor, recipient, drop, attrs) do
    notification
    |> Notification.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:actor, actor)
    |> Ecto.Changeset.put_assoc(:recipient, recipient)
    |> Ecto.Changeset.put_assoc(:drop, drop)
  end

  defp preload_list do
    [:actor, :recipient, :drop]
  end
end
