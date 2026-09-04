defmodule ElixirDrops.Sponsors.SponsorEvent do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "sponsor_events" do
    field :sponsor, :string
    field :placement, :string
    field :kind, :string

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(sponsor_event, attrs) do
    sponsor_event
    |> cast(attrs, [:sponsor, :placement, :kind])
    |> validate_required([:sponsor, :placement, :kind])
    |> validate_inclusion(:kind, ["impression", "click"])
  end
end
