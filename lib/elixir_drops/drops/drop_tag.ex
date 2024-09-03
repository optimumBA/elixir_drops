defmodule ElixirDrops.Drops.DropTag do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.Tag

  @type t :: %__MODULE__{}

  @primary_key false
  @foreign_key_type :binary_id
  schema "drops_tags" do
    belongs_to :drop, Drop
    belongs_to :tag, Tag

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = drop_tag, attrs \\ %{}) do
    drop_tag
    |> cast(attrs, [:tag_id, :drop_id])
    |> validate_required([:tag_id, :drop_id])
  end
end
