defmodule ElixirDrops.Repo.Migrations.UpdateDropNilScreenshotColumns do
  use Ecto.Migration

  def up do
    execute "UPDATE drops SET screenshot = jsonb_build_object('status', 'skipped', 'url', null) WHERE screenshot IS NULL"
  end

  def down do
    execute "UPDATE drops SET screenshot = NULL WHERE screenshot = jsonb_build_object('status', 'skipped', 'url', null)"
  end
end
