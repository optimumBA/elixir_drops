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
    field :body, :string
    field :title, :string
    belongs_to :user, User
    many_to_many :tags, Tag, join_through: DropTag, on_replace: :delete, unique: true

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = drop, attrs \\ %{}) do
    drop
    |> cast(attrs, [:body, :title])
    |> validate_required([:body, :title])
  end
end
