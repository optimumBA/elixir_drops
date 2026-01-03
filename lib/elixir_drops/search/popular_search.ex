defmodule ElixirDrops.Search.PopularSearch do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "popular_searches" do
    field :query, :string
    field :search_count, :integer

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(popular_search, attrs) do
    popular_search
    |> cast(attrs, [:query, :search_count])
    |> validate_required([:query, :search_count])
    |> unique_constraint(:query)
  end
end
