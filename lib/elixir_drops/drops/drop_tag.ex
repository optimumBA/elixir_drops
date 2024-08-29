defmodule ElixirDrops.Drops.DropTag do
  @moduledoc false

  use Ecto.Schema

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.Tag

  @primary_key false
  @foreign_key_type :binary_id
  schema "drops_tags" do
    belongs_to :drop, Drop
    belongs_to :tag, Tag

    timestamps()
  end
end
