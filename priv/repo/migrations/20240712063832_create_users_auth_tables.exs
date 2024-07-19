defmodule ElixirDrops.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :avatar, :string
      add :email, :citext
      add :github_id, :integer
      add :github_username, :string
      add :name, :string

      timestamps()
    end

    create unique_index(:users, [:github_id])

    create table(:users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :context, :string
      add :token, :binary
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
