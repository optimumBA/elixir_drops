defmodule ElixirDropsWeb.DropsSeoTagsExtractorTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Mox

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.S3Helper.Client
  alias ElixirDropsWeb.DropsSeoTagsExtractor

  setup :verify_on_exit!

  defp create_drops_setup(_attrs) do
    user = user_fixture()
    drop = drop_fixture(user)
    drop_with_code = drop_fixture(%Drop{}, user, %{body: "```elixir\n1 + 1\n```"})

    drop_with_image =
      drop_fixture(%Drop{}, user, %{body: "![image](https://example.com/image.png)"})

    %{drop: drop, drop_with_code: drop_with_code, drop_with_image: drop_with_image, user: user}
  end

  describe "create_drop_meta_image/1" do
    setup [:create_drops_setup]

    test "doesn't return an image url if drop doesn't have an image or code block", %{drop: drop} do
      refute DropsSeoTagsExtractor.create_drop_meta_image(drop)
    end

    test "returns an image url if drop has an image", %{drop_with_image: drop} do
      expect(Client.Mock, :upload_image, fn _image, _filename, _type ->
        {:ok, "http://image.com/image.png"}
      end)

      assert "http://image.com/image.png" == DropsSeoTagsExtractor.create_drop_meta_image(drop)
    end

    test "returns an image url if drop has an code block", %{drop_with_code: drop} do
      expect(Client.Mock, :upload_image, fn _image, _filename, _type ->
        {:ok, "http://image.com/image.png"}
      end)

      assert "http://image.com/image.png" == DropsSeoTagsExtractor.create_drop_meta_image(drop)
    end

    test "returns nil if image upload fails", %{drop_with_code: drop} do
      expect(Client.Mock, :upload_image, fn _image, _filename, _type ->
        {:error, "Failed to upload image"}
      end)

      refute DropsSeoTagsExtractor.create_drop_meta_image(drop)
    end
  end
end
