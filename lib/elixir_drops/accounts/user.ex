defmodule ElixirDrops.Accounts.User do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Search.SearchHistory

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :avatar, :string
    field :email, :string
    field :github_id, :integer
    field :github_username, :string
    field :name, :string

    has_many :drops, Drop
    has_many :search_histories, SearchHistory

    timestamps()
  end

  @doc """
  A user changeset for registration.
  """
  @spec user_changeset(t(), map(), any()) ::
          Ecto.Changeset.t()
  def user_changeset(user, attrs, _opts \\ []) do
    user
    |> cast(attrs, [:avatar, :email, :github_id, :github_username, :name])
    |> validate_required([:avatar, :email, :github_id, :github_username, :name])
    |> unique_constraint(:github_id)
  end
end
