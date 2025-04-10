defmodule ElixirDrops.Repo.Migrations.AddScreenshotToDrops do
  use Ecto.Migration

  def change do
    alter table(:drops) do
      add :screenshot, :map
    end
  end
end
