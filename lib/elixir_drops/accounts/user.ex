defmodule ElixirDrops.Accounts.User do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          avatar: String.t() | nil,
          email: String.t() | nil,
          github_id: Integer | nil,
          github_username: String.t() | nil,
          name: String.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :avatar, :string
    field :email, :string
    field :github_id, :integer
    field :github_username, :string
    field :name, :string

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
    |> validate_required([:email, :github_id, :github_username, :name])
    |> unique_constraint(:github_id)
  end
end
