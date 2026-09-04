defmodule ElixirDrops.Repo.Migrations.CreateSponsorEvents do
  use Ecto.Migration

  def change do
    create table(:sponsor_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :sponsor, :string, null: false
      add :placement, :string, null: false
      add :kind, :string, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:sponsor_events, [:sponsor, :placement, :kind, :inserted_at])
  end
end
