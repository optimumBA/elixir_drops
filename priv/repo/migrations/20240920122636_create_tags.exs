defmodule ElixirDrops.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :citext, null: false

      timestamps()
    end

    create unique_index(:tags, [:name])
  end
end
