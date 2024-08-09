defmodule ElixirDrops.S3HelperTest do
  use ExUnit.Case, async: true

  import Mox

  alias ElixirDrops.S3Helper.Client

  setup :verify_on_exit!

  describe "upload_image/3" do
    test "uploads an image" do
      expect(Client.Mock, :upload_image, fn _image, _filename, _type ->
        {:ok, "http://image.com/image.png"}
      end)

      assert Client.upload_image("image", "image.png", "image/png") ==
               {:ok, "http://image.com/image.png"}
    end

    test "fails to upload an image" do
      expect(Client.Mock, :upload_image, fn _image, _filename, _type ->
        {:error, "Failed to upload image"}
      end)

      assert Client.upload_image("image", "image.png", "image/png") ==
               {:error, "Failed to upload image"}
    end
  end
end
