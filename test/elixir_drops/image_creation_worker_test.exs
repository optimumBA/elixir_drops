defmodule ElixirDrops.ImageCreationWorkerTest do
  use ElixirDrops.DataCase, async: true

  use Oban.Testing, repo: ElixirDrops.Repo

  alias ElixirDrops.AccountsFixtures
  alias ElixirDrops.DropsFixtures

  alias ElixirDrops.ImageCreationWorker

  # alias ElixirDropsWeb.DropsSeoTagsExtractor

  defp create_drops_setup(_attrs) do
    user = AccountsFixtures.user_fixture()
    drop = DropsFixtures.drop_fixture(user)

    %{drop: drop, user: user}
  end

  describe "perform/1" do
    setup [:create_drops_setup]

    test "create_drop_seo_image/2 with valid data creates a drop", %{drop: drop, user: user} do
      assert :ok = perform_job(ImageCreationWorker, %{"drop_id" => drop.id, "user_id" => user.id})
    end

  end
end
