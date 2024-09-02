defmodule ElixirDrops.Repo.Migrations.CreateDropsTags do
  use Ecto.Migration

  def change do
    create table(:drops_tags, primary_key: false) do
      add :drop_id, references(:drops, type: :binary_id, on_delete: :delete_all)
      add :tag_id, references(:tags, type: :binary_id)

      timestamps()
    end

    create index(:drops_tags, [:drop_id])
    create index(:drops_tags, [:tag_id])

    create unique_index(:drops_tags, [:drop_id, :tag_id])
  end
end
