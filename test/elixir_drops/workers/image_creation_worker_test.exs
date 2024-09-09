defmodule ElixirDrops.Workers.ImageCreationWorkerTest do
  use ElixirDrops.DataCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Mox

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.S3Helper.Client
  alias ElixirDrops.Workers.ImageCreationWorker

  setup :set_mox_global
  setup :set_mox_global
  setup :verify_on_exit!

  defp drop_setup(_attrs) do
    drop_body = ~S"""
    Lorem ipsum odor amet, consectetuer adipiscing elit. Habitant cras lacinia pellentesque potenti faucibus quam turpis. \n```go\npackage main\n\nimport \"fmt\"\n\nfunc main() {\n\tfmt.Println(\"Hello, 世界\")\n}\n```\n Cursus vestibulum lobortis lectus nam, nec ullamcorper pellentesque. \n```js\nconst new = () => {\n    console.log(\"js\")\n}\n```\nNunc dignissim magna dapibus mauris malesuada duis. Vivamus augue risus volutpat lacus dolor.\n
    """

    user = user_fixture()
    drop = drop_fixture(%Drop{}, user, %{title: "Drop title", body: drop_body})

    %{drop: drop, user: user}
  end

  describe "perform/1" do
    setup [:drop_setup]

    test "updates the drop with an image url if it has a code block",
         %{drop: drop} do
      timestamp = Timex.to_unix(drop.updated_at)

      image_url = "http://image.com/drop-meta-image-#{timestamp}-#{drop.id}.png"

      expect(Client.Mock, :upload_image, fn _image, _filename, _type ->
        {:ok, image_url}
      end)

      args = %{drop_id: drop.id}

      assert :ok = perform_job(ImageCreationWorker, args)
      assert %Drop{} = drop = Drops.get_drop(drop.id)

      assert drop.seo_image_link == image_url
    end

    test "seo_image_link is not updated if there are errors", %{drop: drop} do
      expect(Client.Mock, :upload_image, fn _image, _filename, _type ->
        {:error, "Failed to upload image"}
      end)

      args = %{drop_id: drop.id}

      assert :ok = perform_job(ImageCreationWorker, args)
      assert %Drop{} = drop = Drops.get_drop(drop.id)

      refute drop.seo_image_link
    end

    test "seo_image_link is nil if there is no code block", %{user: user} do
      drop = drop_fixture(user)

      args = %{drop_id: drop.id}

      assert :ok = perform_job(ImageCreationWorker, args)

      assert %Drop{} = drop = Drops.get_drop(drop.id)
      refute drop.seo_image_link
    end
  end
end
