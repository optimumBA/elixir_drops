defmodule ElixirDrops.Repo.Migrations.SkipExistingScreenshots do
  use Ecto.Migration

  @spec up() :: term()
  def up do
    execute """
    UPDATE drops SET screenshot = '{"internal_url": null, "meta_url": null, "status": "skipped"}'
    """
  end

  @spec down() :: term()
  def down do
    execute """
    UPDATE drops SET screenshot = '{"status": "skipped", "url": null}'
    """
  end
end
