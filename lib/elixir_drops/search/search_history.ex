defmodule ElixirDrops.Search.SearchHistory do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "search_histories" do
    field :query, :string
    field :results_count, :integer
    field :user_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(search_history, attrs) do
    changeset =
      search_history
      |> cast(attrs, [:query, :results_count, :user_id])
      |> validate_required([:query, :user_id])

    # Set default results_count to 0 if not provided
    if get_change(changeset, :results_count) == nil and search_history.results_count == nil do
      put_change(changeset, :results_count, 0)
    else
      changeset
    end
  end
end
