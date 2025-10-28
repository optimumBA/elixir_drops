defmodule ElixirDrops.Repo.Migrations.CreateBookmarks do
  use Ecto.Migration

  def change do
    create table(:bookmarks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :drop_id, references(:drops, on_delete: :delete_all, type: :binary_id)
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id)

      timestamps()
    end

    create unique_index(:bookmarks, [:user_id, :drop_id], name: :bookmarks_user_id_drop_id_index)
  end
end
