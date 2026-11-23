defmodule ElixirDrops.Bookmarks.Bookmark do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Drops.Drop

  @type attrs :: map()
  @type changeset :: Ecto.Changeset.t()
  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "bookmarks" do
    belongs_to :drop, Drop
    belongs_to :user, User

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t(), attrs()) :: changeset()
  def changeset(%__MODULE__{} = bookmark, attrs) do
    bookmark
    |> cast(attrs, [:drop_id, :user_id])
    |> validate_required([:drop_id, :user_id])
    |> foreign_key_constraint(:drop_id)
    |> foreign_key_constraint(:user_id)
  end
end
