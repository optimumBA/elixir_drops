defmodule ElixirDrops.Repo.Migrations.RenameFieldUniqueUrlStringToShortId do
  use Ecto.Migration

  def up do
    drop_if_exists unique_index(:drops, [:unique_url_string])

    rename table(:drops), :unique_url_string, to: :short_id

    create unique_index(:drops, [:short_id])
  end

  def down do
    drop_if_exists unique_index(:drops, [:short_id])

    rename table(:drops), :short_id, to: :unique_url_string

    create unique_index(:drops, [:unique_url_string])
  end
end
