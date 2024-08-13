defmodule ElixirDrops.Repo.Migrations.AddSeoImageLink do
  use Ecto.Migration

  def change do
    alter table(:drops) do
      add :seo_image_link, :string
    end
  end
end
