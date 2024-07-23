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
  end
end
