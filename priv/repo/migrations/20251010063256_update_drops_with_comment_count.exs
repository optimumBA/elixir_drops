defmodule ElixirDrops.Repo.Migrations.UpdateDropsWithCommentCount do
  use Ecto.Migration

  def change do
    alter table(:drops) do
      add :comment_count, :integer
    end
  end
end
