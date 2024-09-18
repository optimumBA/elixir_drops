defmodule ElixirDrops.Repo.Migrations.AddDropImage do
  use Ecto.Migration

  def change do
    alter table(:drops) do
      add(:drop_image, :string)
    end
  end
end
