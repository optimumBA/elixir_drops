defmodule ElixirDrops.Workers.ScreenshotGeneratorWorkerTest do
  use ElixirDrops.DataCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import ExUnit.CaptureLog
  import Mox

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.S3Helper.Client
  alias ElixirDrops.Workers.ScreenshotGeneratorWorker

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

    test "creates a screenshot for a drop with a code block",
         %{drop: drop} do
      timestamp = Timex.to_unix(drop.updated_at)

      image_url = "http://image.com/drop-meta-image-#{timestamp}-#{drop.id}.png"

      Client.Mock
      |> expect(:upload_image, fn _image, _filename, _type ->
        {:ok, image_url}
      end)
      |> expect(:get_image, fn _drop -> {:ok, image_url} end)

      assert :ok = perform_job(ScreenshotGeneratorWorker, %{drop_id: drop.id})

      assert {:ok, _image_url} = Client.get_image(drop)
    end

    test "does not create a screenshot when there is an error", %{drop: drop} do
      Client.Mock
      |> expect(:upload_image, fn _image, _filename, _type ->
        {:error, "Failed to upload image"}
      end)
      |> expect(:get_image, fn _drop -> {:error, "Image not found"} end)

      log_output =
        capture_log(fn ->
          assert :ok = perform_job(ScreenshotGeneratorWorker, %{drop_id: drop.id})
        end)

      assert log_output =~ "Failed to upload image"

      assert {:error, "Image not found"} = Client.get_image(drop)
    end

    test "no screenshot is created if a drop has no code block", %{user: user} do
      expect(Client.Mock, :get_image, fn _drop ->
        {:error, "Image not found"}
      end)

      drop = drop_fixture(user)

      log_output =
        capture_log(fn ->
          assert :ok = perform_job(ScreenshotGeneratorWorker, %{drop_id: drop.id})
        end)

      assert log_output =~ "No code block found"

      assert Client.get_image(drop) == {:error, "Image not found"}
    end

    test "does not create a screenshot for a non-existent drop" do
      drop_id = Ecto.UUID.generate()

      log_output =
        capture_log(fn ->
          assert :ok = perform_job(ScreenshotGeneratorWorker, %{drop_id: drop_id})
        end)

      assert log_output =~ "Drop not found"
    end
  end
end
