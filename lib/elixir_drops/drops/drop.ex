defmodule ElixirDrops.Drops.Drop do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Drops.DropTag
  alias ElixirDrops.Drops.Tag

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "drops" do
    field :title, :string
    field :body, :string

    belongs_to :user, User

    many_to_many :tags, Tag, join_through: DropTag, on_replace: :delete

    timestamps()
  end

  @spec changeset(t(), list(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = drop, tags, attrs \\ %{}) do
    drop
    |> cast(attrs, [:body, :title, :user_id])
    |> validate_required([:body, :title])
    |> put_assoc(:tags, tags)
  end
end
