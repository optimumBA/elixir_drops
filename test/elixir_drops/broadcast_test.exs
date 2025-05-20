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
        body: "This is a new drop.",
        id: 1,
        short_id: "abc123",
        title: "New Drop",
        user_id: 1
      }

      assert :ok == DropsBroadcast.broadcast_drop_creation(drop)
      assert_receive {DropsBroadcast, [:drop, :created], ^drop}
    end
  end

  describe "broadcast_drop_screenshot_started/1" do
    test "broadcasts a message indicating that a drop screenshot is being generated" do
      DropsBroadcast.subscribe()

      drop = %Drop{
        body: "This is a new drop. ```elixir\nIO.puts(\"Hello, world!\")```",
        id: 1,
        short_id: "abc123",
        title: "New Drop",
        user_id: 1
      }

      assert :ok == DropsBroadcast.broadcast_drop_screenshot_started(drop)
      assert_receive {DropsBroadcast, [:drop, :screenshot_generation_started], ^drop}
    end
  end

  describe "broadcast_drop_screenshot_completion/2" do
    test "broadcasts a message indicating that a drop screenshot has been generated" do
      DropsBroadcast.subscribe()

      drop = %Drop{
        body: "This is a new drop. ```elixir\nIO.puts(\"Hello, world!\")```",
        id: 1,
        short_id: "abc123",
        title: "New Drop",
        user_id: 1
      }

      assert :ok == DropsBroadcast.broadcast_drop_screenshot_completion(drop, 100, :completed)

      assert_receive {DropsBroadcast, [:drop, :screenshot_generation_completion], ^drop, 100,
                      :completed, %{action: "new"}}
    end
  end
end
