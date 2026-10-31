defmodule ElixirDrops.Repo.Migrations.UpdateMissingScreenshots do
  use Ecto.Migration

  @spec up() :: term()
  def up do
    execute """
    UPDATE drops SET screenshot = '{"status": "skipped", "url": null}' WHERE screenshot IS NULL
    """
  end

  @spec down() :: term()
  def down do
    execute "UPDATE drops SET screenshot = NULL WHERE screenshot->>'status' = 'skipped'"
  end
end
