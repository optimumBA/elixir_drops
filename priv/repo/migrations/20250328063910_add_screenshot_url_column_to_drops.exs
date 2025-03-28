defmodule ElixirDrops.Repo.Migrations.AddScreenshotUrlColumnToDrops do
  use Ecto.Migration

  def change do
    alter table(:drops) do
      add :screenshot_url, :string
    end
  end
end
