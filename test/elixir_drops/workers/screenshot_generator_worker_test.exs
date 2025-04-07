defmodule ElixirDrops.Workers.ScreenshotGeneratorWorkerTest do
  use ElixirDrops.DataCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Mox

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.S3Helper.Client
  alias ElixirDrops.Workers.ScreenshotGeneratorWorker

  setup :set_mox_global
  setup :verify_on_exit!

  @drop_body ~S"""
  Lorem ipsum odor amet, consectetuer adipiscing elit.

  Habitant cras lacinia pellentesque potenti faucibus quam turpis.

  ```go
  package main

  import "fmt"

  func main() {
    fmt.Println("Hello, 世界")
  }
  ```

  Cursus vestibulum lobortis lectus nam, nec ullamcorper pellentesque.

  ```js
  const new = () => {
    console.log("js")
  }
  ```

  Nunc dignissim magna dapibus mauris malesuada duis. Vivamus augue risus volutpat lacus dolor.
  """

  defp drop_setup(_attrs) do
    user = user_fixture()
    drop = drop_fixture(%Drop{}, user, %{title: "Drop title", body: @drop_body})

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

      {:error, "Failed to upload image"} =
        perform_job(ScreenshotGeneratorWorker, %{drop_id: drop.id})

      assert {:error, "Image not found"} = Client.get_image(drop)
    end

    test "does not create a screenshot when there is no code block and the job is not retried", %{
      user: user
    } do
      drop = drop_fixture(user)

      {:cancel, "No code block found"} =
        perform_job(ScreenshotGeneratorWorker, %{drop_id: drop.id})
    end

    test "does not create a screenshot for a non-existent drop" do
      drop_id = Ecto.UUID.generate()

      {:cancel, "No code block found"} =
        perform_job(ScreenshotGeneratorWorker, %{drop_id: drop_id})
    end

    test "creates a screenshot when the code block changes", %{drop: drop, user: user} do
      updated_body = ~S"""
      ```elixir
      IO.write("Hello World!")
      ```
      """

      # Simulate drop body update with a changed code block
      Drops.update_drop(drop, user, %{body: updated_body})

      timestamp = Timex.to_unix(drop.updated_at)
      image_url = "http://image.com/drop-meta-image-#{timestamp}-#{drop.id}.png"

      expect(Client.Mock, :upload_image, fn _image, _filename, _type -> {:ok, image_url} end)

      assert :ok =
               perform_job(ScreenshotGeneratorWorker, %{
                 drop_id: drop.id,
                 action: "edit",
                 old_body: drop.body
               })
    end

    test "does not create  screenshot when the code block does not change", %{
      drop: drop,
      user: user
    } do
      updated_body = @drop_body <> "Small change."

      Drops.update_drop(drop, user, %{body: updated_body})

      assert {:cancel, "Code block unchanged"} =
               perform_job(ScreenshotGeneratorWorker, %{
                 drop_id: drop.id,
                 action: "edit",
                 old_body: drop.body
               })
    end

    test "does not create screenshot when the title changes", %{
      drop: drop,
      user: user
    } do
      updated_title = "This is the new title"

      # Simulate drop body update with a changed code block
      Drops.update_drop(drop, user, %{title: updated_title})

      assert {:cancel, "Code block unchanged"} =
               perform_job(ScreenshotGeneratorWorker, %{
                 drop_id: drop.id,
                 action: "edit",
                 old_body: drop.body
               })
    end

    test "calc_height returns 0 when body has no markdown code block" do
      body = "fjdjdjd\n"
      assert ScreenshotGeneratorWorker.calc_height(body) == "0"
    end
  end
end
