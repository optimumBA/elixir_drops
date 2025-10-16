defmodule ElixirDrops.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :deleted_at, :utc_datetime_usec
      add :edited_at, :utc_datetime_usec
      add :drop_id, references(:drops, on_delete: :delete_all, type: :binary_id), null: false
      add :parent_id, references(:comments, on_delete: :nilify_all, type: :binary_id)
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create index(:comments, [:drop_id])
    create index(:comments, [:parent_id])
    create index(:comments, [:user_id])
  end
end
