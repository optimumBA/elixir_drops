defmodule ElixirDrops.Accounts do
  @moduledoc """
  The Accounts context.
  Implements functions for user manipulation.
  """

  import Ecto.Query, warn: false

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Accounts.UserToken
  alias ElixirDrops.Repo

  @type changeset :: Ecto.Changeset.t()
  @type github_id :: Integer
  @type user :: User.t()
  @type user_id :: Ecto.UUID.t()
  @type token :: binary()

  @doc """
    Gets a single user.
    Raises `Ecto.NoResultsError` if the User does not exist.

    ## Examples

        iex> get_user!(123)
        %User{}

        iex> get_user!(456)
        ** (Ecto.NoResultsError)

  """
  @spec get_user!(user_id()) :: user()
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets or creates a single user.
  Returns the single user if user exists or creates the one instead.

    ## Examples

    iex> get_or_create_user(%{field: value})
    {:ok, %User{}}

  Otherwise it returns error tuple with changeset.
  """
  @spec get_or_create_user(map()) :: {:ok, user()} | {:error, changeset()}
  def get_or_create_user(%{github_id: github_id} = user) do
    case get_user_by_github_id(github_id) do
      {:error, _reason} ->
        register_user(user)

      {:ok, user} ->
        {:ok, user}
    end
  end

  @doc """
  Gets a user Github ID.

    ## Examples

        iex> get_user_by_github_id(2_546_302)
        {:ok, %User{}}

        iex> get_user_by_github_id(4444)
        {:error, "User not found!"}

  """
  @spec get_user_by_github_id(github_id()) :: {:ok, user()} | {:error, binary()}
  def get_user_by_github_id(github_id) do
    case Repo.get_by(User, github_id: github_id) do
      nil -> {:error, "User not found!"}
      user -> {:ok, user}
    end
  end

  @doc """
  Registers a user.

    ## Examples

        iex> register_user(%{field: value})
        {:ok, %User{}}

        iex> register_user(%{field: bad_value})
        {:error, %Ecto.Changeset{}}

  """
  @spec register_user(map()) :: {:ok, user()} | {:error, changeset()}
  def register_user(attrs \\ %{}) do
    %User{}
    |> change_user(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

    ## Examples

        iex> update_user(user, %{field: new_value})
        {:ok, %User{}}

        iex> update_user(user, %{field: bad_value})
        {:error, %Ecto.Changeset{}}

  """
  @spec update_user(user(), map()) :: {:ok, user()} | {:error, changeset()}
  def update_user(%User{} = user, attrs) do
    user
    |> change_user(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

    ## Examples

        iex> delete_user(user)
        {:ok, %User{}}

        iex> delete_user(user)
        {:error, %Ecto.Changeset{}}

  """
  @spec delete_user(user()) :: {:ok, user()} | {:error, changeset()}
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

    ## Examples

        iex> change_user(user)
        %Ecto.Changeset{data: %User{}}

  """
  @spec change_user(user(), map()) :: changeset()
  def change_user(%User{} = user, attrs \\ %{}) do
    User.user_changeset(user, attrs)
  end

  @doc """
  Generates a session token for user.

    ## Examples

       iex> generate_user_session_token(user)
       <<43, 31, 68, 123, 207, 25, 230, 145, 231, 37, 255, 19, 202, 97, 185, 208, 211, 12, 250, 234,
         146, 220, 49, 98, 66, 156, 233, 191, 119, 77, 80, 251>>

  """
  @spec generate_user_session_token(user()) :: binary()
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

    ## Examples

        iex> get_user_by_session_token(token)
        %ElixirDrops.Accounts.User{}

        iex> get_user_by_session_token(nil)
        nil

  """
  @spec get_user_by_session_token(token() | nil) :: user() | nil
  def get_user_by_session_token(nil), do: nil

  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes all remaining tokens from db that belong to user.

    ## Examples

        iex> clear_all_tokens_for_user(%ElixirDrops.Accounts.User{})
        :ok

  """
  @spec clear_all_tokens_for_user(user()) :: :ok
  def clear_all_tokens_for_user(user) do
    q = UserToken.user_and_contexts_query(user, :all)
    Repo.delete_all(q)
    :ok
  end

  @doc """
  Deletes the signed token with the given context.

    ## Examples

        iex> delete_user_session_token(token)
        :ok

  """
  @spec delete_user_session_token(token()) :: :ok
  def delete_user_session_token(token) do
    query = UserToken.token_and_context_query(token, "session")
    Repo.delete_all(query)

    :ok
  end
end
