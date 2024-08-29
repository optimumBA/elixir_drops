defmodule ElixirDrops.Drops.Tag do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.DropTag

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tags" do
    field :name, :string

    many_to_many :drops, Drop, join_through: DropTag

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = tag, attrs \\ %{}) do
    tag
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  def parse_tags(tags) do
    (tags || "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
