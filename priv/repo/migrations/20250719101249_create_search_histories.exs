defmodule ElixirDrops.Repo.Migrations.CreateSearchHistories do
  use Ecto.Migration

  def change do
    create table(:search_histories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :query, :string
      add :results_count, :integer
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:search_histories, [:user_id])
    create index(:search_histories, [:user_id, :inserted_at])
    create index(:search_histories, [:query])
  end
end
