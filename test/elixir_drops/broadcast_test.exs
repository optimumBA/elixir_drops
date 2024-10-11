defmodule ElixirDrops.BroadcastTest do
  use ExUnit.Case, async: true
  alias ElixirDrops.Drops
  alias ElixirDrops.DropsBroadcast

  describe "subscribe and broacast tests" do
    test "returns :ok and subscribes caller to the drops topic" do
      assert :ok == DropsBroadcast.subscribe()
    end

    test "broadcasts a message indicating that a new drop has been created" do
      drop = %Drops.Drop{
        id: 1,
        title: "New Drop",
        body: "This is a new drop.",
        user_id: 1,
        short_id: "abc123"
      }

      assert :ok == DropsBroadcast.broadcast_drop_creation(drop)
    end
  end
end
