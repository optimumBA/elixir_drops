defmodule ElixirDrops.Repo.Migrations.CreatePopularSearches do
  use Ecto.Migration

  def change do
    create table(:popular_searches, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :query, :string
      add :search_count, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:popular_searches, [:query])
    create index(:popular_searches, [:search_count])
  end
end
