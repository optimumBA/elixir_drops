defmodule ElixirDrops.S3HelperTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Mox

  alias ElixirDrops.S3Helper.Client

  setup :verify_on_exit!

  defp create_drops_setup(_attrs) do
    user = user_fixture()
    drop = drop_fixture(user)

    %{drop: drop, user: user}
  end

  describe "upload_image/3" do
    test "image upload is successful" do
      expect(Client.Mock, :upload_image, fn _image, _filename, _type ->
        {:ok, "http://image.com/image.png"}
      end)

      assert Client.upload_image("image", "image.png", "image/png") ==
               {:ok, "http://image.com/image.png"}
    end

    test "image upload fails" do
      expect(Client.Mock, :upload_image, fn _image, _filename, _type ->
        {:error, "Failed to upload image"}
      end)

      assert Client.upload_image("image", "image.png", "image/png") ==
               {:error, "Failed to upload image"}
    end
  end

  describe "get_image/1" do
    setup [:create_drops_setup]

    test "returns an image url if image exists", %{drop: drop} do
      expect(Client.Mock, :get_image, fn _drop ->
        {:ok, "http://image.com/image.png"}
      end)

      assert Client.get_image(drop, :meta) ==
               {:ok, "http://image.com/image.png"}
    end

    test "returns an error if image does not exist", %{drop: drop} do
      expect(Client.Mock, :get_image, fn _drop ->
        {:error, "Image not found"}
      end)

      assert Client.get_image(drop, :meta) ==
               {:error, "Image not found"}
    end
  end
end
