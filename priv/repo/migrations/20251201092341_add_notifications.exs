defmodule ElixirDrops.Repo.Migrations.AddNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :actor_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      add :comment_id, references(:comments, on_delete: :delete_all, type: :binary_id),
        null: false

      add :recipient_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :read, :boolean, default: false, null: false
      add :type, :string, null: false

      timestamps()
    end
  end
end
