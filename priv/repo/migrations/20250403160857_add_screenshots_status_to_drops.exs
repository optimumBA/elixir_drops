defmodule ElixirDrops.Repo.Migrations.AddScreenshotsStatusToDrops do
  use Ecto.Migration

  def change do
    alter table(:drops) do
      add :screenshot_status, :string
    end
  end
end
