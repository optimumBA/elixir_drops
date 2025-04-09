defmodule ElixirDrops.Repo.Migrations.AddScreenshotEmbed do
  use Ecto.Migration

  def change do
    alter table(:drops) do
      add :screenshot, :map, default: %{}, null: false
    end
  end
end
