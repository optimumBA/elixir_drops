defmodule ElixirDrops.Repo.Migrations.CreateBookmarks do
  use Ecto.Migration

  @spec change() :: term()
  def change do
    create table(:bookmarks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :drop_id, references(:drops, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:bookmarks, [:user_id, :drop_id])
    create index(:bookmarks, [:drop_id])
    create index(:bookmarks, [:user_id, :inserted_at, :id])
  end
end
