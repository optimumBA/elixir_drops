defmodule ElixirDrops.Workers.ScreenshotGeneratorWorkerTest do
  use ElixirDrops.DataCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Mox

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.S3Helper.Client
  alias ElixirDrops.WallabyAdapter
  alias ElixirDrops.Workers.ScreenshotGeneratorWorker
  alias ElixirDrops.Workers.SitemapGeneratorWorker

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

  describe "perform/1" do
    setup do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user, %{title: "Drop title", body: @drop_body})

      # Create temp screenshot files upfront — on_exit can't be called from FLAME worker process
      meta_path = temp_screenshot_path()
      internal_path = temp_screenshot_path()
      File.write!(meta_path, :crypto.strong_rand_bytes(128))
      File.write!(internal_path, :crypto.strong_rand_bytes(128))

      on_exit(fn ->
        File.rm(meta_path)
        File.rm(internal_path)
      end)

      %{drop: drop, user: user, meta_path: meta_path, internal_path: internal_path}
    end

    test "creates two screenshots for a drop with a code block and enqueues a sitemap job", %{
      drop: drop,
      meta_path: meta_path,
      internal_path: internal_path
    } do
      %{meta_image_url: meta_image_url, internal_image_url: internal_image_url} =
        screenshot_upload_mock(drop)

      wallaby_mock_success(meta_path, internal_path)

      assert :ok = perform_job(ScreenshotGeneratorWorker, %{drop_id: drop.id})

      updated_drop = Repo.reload(drop)
      assert updated_drop.screenshot.status == :completed
      assert updated_drop.screenshot.meta_url == meta_image_url
      assert updated_drop.screenshot.internal_url == internal_image_url

      assert_enqueued(
        worker: SitemapGeneratorWorker,
        args: %{"drop_id" => updated_drop.id},
        queue: "seo_sitemap"
      )
    end

    test "properly handles meta screenshot upload failure", %{
      drop: drop,
      meta_path: meta_path,
      internal_path: internal_path
    } do
      wallaby_mock_success(meta_path, internal_path)

      expect(Client.Mock, :upload_image, 2, fn _image, filename, _type ->
        case filename do
          "drop-meta-image-latest-" <> _id ->
            {:error, "Failed to upload meta image"}

          "drop-internal-image-latest-" <> _id ->
            {:ok, "http://image.com/drop-internal-image-latest-#{drop.id}.png"}
        end
      end)

      {:error, "Failed to upload meta screenshot"} =
        perform_job(ScreenshotGeneratorWorker, %{drop_id: drop.id})

      updated_drop = Repo.reload(drop)
      assert updated_drop.screenshot.status == :failed
      refute updated_drop.screenshot.internal_url
      refute updated_drop.screenshot.meta_url
    end

    test "properly handles internal screenshot upload failure", %{
      drop: drop,
      meta_path: meta_path,
      internal_path: internal_path
    } do
      wallaby_mock_success(meta_path, internal_path)

      expect(Client.Mock, :upload_image, 2, fn _image, filename, _type ->
        case filename do
          "drop-meta-image-latest-" <> _id ->
            {:ok, "http://image.com/drop-meta-image-latest-#{drop.id}.png"}

          "drop-internal-image-latest-" <> _id ->
            {:error, "Failed to upload internal image"}
        end
      end)

      {:error, "Failed to upload internal screenshot"} =
        perform_job(ScreenshotGeneratorWorker, %{drop_id: drop.id})

      updated_drop = Repo.reload(drop)
      assert updated_drop.screenshot.status == :failed
      refute updated_drop.screenshot.internal_url
      refute updated_drop.screenshot.meta_url
    end

    test "handles both screenshots failing", %{
      drop: drop,
      meta_path: meta_path,
      internal_path: internal_path
    } do
      wallaby_mock_success(meta_path, internal_path)

      expect(Client.Mock, :upload_image, 2, fn _image, filename, _type ->
        case filename do
          "drop-meta-image-latest-" <> _id ->
            {:error, "Failed to upload meta image"}

          "drop-internal-image-latest-" <> _id ->
            {:error, "Failed to upload internal image"}
        end
      end)

      {:error, "Failed to upload both screenshots"} =
        perform_job(ScreenshotGeneratorWorker, %{drop_id: drop.id})

      updated_drop = Repo.reload(drop)
      assert updated_drop.screenshot.status == :failed
      refute updated_drop.screenshot.internal_url
      refute updated_drop.screenshot.meta_url
    end

    test "does not create a screenshot for a non-existent drop" do
      drop_id = Ecto.UUID.generate()

      {:error, "Drop not found"} =
        perform_job(ScreenshotGeneratorWorker, %{drop_id: drop_id})
    end

    test "creates a screenshot when the code block changes and enqueues a sitemap job", %{
      drop: drop,
      meta_path: meta_path,
      internal_path: internal_path,
      user: user
    } do
      updated_body = ~S"""
      ```elixir
      IO.write("Hello World!")
      ```
      """

      Drops.update_drop(drop, user, %{body: updated_body})

      %{meta_image_url: meta_image_url, internal_image_url: internal_image_url} =
        screenshot_upload_mock(drop)

      wallaby_mock_success(meta_path, internal_path)

      assert :ok =
               perform_job(ScreenshotGeneratorWorker, %{
                 drop_id: drop.id,
                 action: "edit",
                 old_body: drop.body
               })

      updated_drop = Repo.reload(drop)
      assert updated_drop.screenshot.status == :completed
      assert updated_drop.screenshot.meta_url == meta_image_url
      assert updated_drop.screenshot.internal_url == internal_image_url

      assert_enqueued(
        worker: SitemapGeneratorWorker,
        args: %{"drop_id" => updated_drop.id},
        queue: "seo_sitemap"
      )
    end
  end

  defp screenshot_upload_mock(drop) do
    meta_image_url = "http://image.com/drop-meta-image-latest-#{drop.id}.png"
    internal_image_url = "http://image.com/drop-internal-image-latest-#{drop.id}.png"

    expect(Client.Mock, :upload_image, 2, fn _image, filename, _type ->
      case filename do
        "drop-meta-image-latest-" <> _id ->
          assert meta_image_url == "http://image.com/drop-meta-image-latest-#{drop.id}.png"
          {:ok, meta_image_url}

        "drop-internal-image-latest-" <> _id ->
          assert internal_image_url ==
                   "http://image.com/drop-internal-image-latest-#{drop.id}.png"

          {:ok, internal_image_url}
      end
    end)

    %{meta_image_url: meta_image_url, internal_image_url: internal_image_url}
  end

  defp wallaby_mock_success(meta_path, internal_path) do
    paths = [meta_path, internal_path]
    path_agent = elem(Agent.start_link(fn -> paths end), 1)

    # Called twice: once for meta, once for internal screenshot
    expect(WallabyAdapter.Mock, :start_session, 2, fn _capabilities ->
      screenshot_path = Agent.get_and_update(path_agent, fn [h | t] -> {h, t} end)
      session = %Wallaby.Session{screenshots: [screenshot_path]}
      {:ok, session}
    end)

    expect(WallabyAdapter.Mock, :visit, 2, fn session, _url -> session end)

    expect(WallabyAdapter.Mock, :take_screenshot, 2, fn session -> session end)

    expect(WallabyAdapter.Mock, :end_session, 2, fn _session -> :ok end)
  end

  defp temp_screenshot_path do
    Path.join(System.tmp_dir!(), "test_screenshot_#{System.unique_integer([:positive])}.png")
  end
end
