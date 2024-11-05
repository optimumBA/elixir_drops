defmodule ElixirDrops.Repo.Migrations.AddUniqueUrlString do
  use Ecto.Migration

  def change do
    alter table(:drops) do
      add :unique_url_string, :string, null: false, default: ""
    end

    create unique_index(:drops, [:unique_url_string])
  end
end
