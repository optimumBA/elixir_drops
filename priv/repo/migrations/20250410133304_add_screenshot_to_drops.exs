defmodule ElixirDrops.Repo.Migrations.AddScreenshotToDrops do
  use Ecto.Migration

  @spec change() :: term()
  def change do
    alter table(:drops) do
      add :screenshot, :map
    end
  end
end
