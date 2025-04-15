defmodule ElixirDrops.BroadcastTest do
  use ExUnit.Case, async: true
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.DropsBroadcast

  describe "subscribe/0" do
    test "returns :ok and subscribes caller to the drops topic" do
      assert :ok == DropsBroadcast.subscribe()
    end
  end

  describe "broadcast_drop_creation/1" do
    test "broadcasts a message indicating that a new drop has been created" do
      DropsBroadcast.subscribe()

      drop = %Drop{
        id: 1,
        title: "New Drop",
        body: "This is a new drop.",
        user_id: 1,
        short_id: "abc123"
      }

      assert :ok == DropsBroadcast.broadcast_drop_creation(drop)
      assert_receive {DropsBroadcast, [:drop, :created], ^drop}
    end
  end

  describe "broadcast_drop_screenshot_progress/2" do
    test "broadcasts a message indicating that a drop screenshot is being generated" do
      DropsBroadcast.subscribe()

      drop = %Drop{
        id: 1,
        title: "New Drop",
        body: "This is a new drop.",
        user_id: 1,
        short_id: "abc123"
      }

      assert :ok == DropsBroadcast.broadcast_drop_screenshot_progress(drop, 10, :pending)

      assert_receive {DropsBroadcast, [:drop, :screenshot_generation_progress], ^drop, 10,
                      :pending, %{action: "new"}}
    end
  end
end
