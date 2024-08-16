defmodule ElixirDrops.S3HelperTest do
  use ExUnit.Case, async: true

  import Mox

  alias ElixirDrops.S3Helper.Client

  setup :verify_on_exit!

  describe "upload_image/3" do
    test "uploads an image" do
      expect(Client.Mock, :upload_image, fn _image, _filename, _type, _retries ->
        {:ok, "http://image.com/image.png"}
      end)

      assert Client.upload_image("image", "image.png", "image/png", 0) ==
               {:ok, "http://image.com/image.png"}
    end

    test "retries upload and returns an error if upload fails after all retries" do
      expect(Client.Mock, :upload_image, 4, fn _image, _filename, _type, _retries ->
        {:error, "Failed to upload image"}
      end)

      assert Client.upload_image("image", "image.png", "image/png", 0) ==
               {:error, "Failed to upload image"}
    end
  end
end
