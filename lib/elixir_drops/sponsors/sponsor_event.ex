defmodule ElixirDrops.Sponsors.SponsorEvent do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @type attrs :: map()
  @type changeset :: Ecto.Changeset.t()
  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "sponsor_events" do
    field :kind, :string
    field :placement, :string
    field :sponsor, :string

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  @spec changeset(t(), attrs()) :: changeset()
  def changeset(sponsor_event, attrs) do
    sponsor_event
    |> cast(attrs, [:kind, :placement, :sponsor])
    |> validate_required([:kind, :placement, :sponsor])
    |> validate_inclusion(:kind, ["impression", "visible_impression", "click"])
  end
end
