defmodule ElixirDrops.Repo.Migrations.CreateDrops do
  use Ecto.Migration

  def change do
    create table(:drops, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text
      add :title, :string
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id)

      timestamps()
    end

    create index(:drops, [:user_id])
  end
end
