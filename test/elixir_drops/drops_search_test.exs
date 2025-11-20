defmodule ElixirDrops.DropsSearchTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop

  describe "search functionality" do
    test "filters drops correctly by search query" do
      user = user_fixture()

      # Create drops with specific content for testing
      {:ok, matching_drop} =
        Drops.create_drop(%Drop{}, user, %{
          title: "Phoenix Tutorial",
          body: "Learning Phoenix framework"
        })

      {:ok, _non_matching_drop} =
        Drops.create_drop(%Drop{}, user, %{
          title: "Random Drop",
          body: "Not related content"
        })

      # Test search filtering
      search_results = Drops.list_drops(%{user_id: user.id, search: "phoenix"}, %{})

      # Should only return the matching drop
      assert length(search_results) == 1
      assert hd(search_results).id == matching_drop.id
      assert hd(search_results).title == "Phoenix Tutorial"

      # Test that both drops exist without search
      all_drops = Drops.list_drops(%{user_id: user.id}, %{})
      assert length(all_drops) == 2
    end

    test "case insensitive search works" do
      user = user_fixture()

      {:ok, drop} =
        Drops.create_drop(%Drop{}, user, %{
          title: "Phoenix Tutorial",
          body: "Learning Phoenix"
        })

      # Test different cases
      for query <- ["phoenix", "Phoenix", "PHOENIX"] do
        results = Drops.list_drops(%{user_id: user.id, search: query}, %{})
        assert length(results) == 1
        assert hd(results).id == drop.id
      end
    end

    test "filters drops correctly using drop_fixture (like LiveView test)" do
      user = user_fixture()

      # Create drops using the same method as the failing LiveView test
      _matching_drop =
        drop_fixture(%Drop{}, user, %{title: "Phoenix Tutorial", body: "Learning Phoenix"})

      _non_matching_drop =
        drop_fixture(%Drop{}, user, %{title: "Random Drop", body: "Not related"})

      # Test search filtering
      search_results = Drops.list_drops(%{user_id: user.id, search: "phoenix"}, %{})

      # Should only return the matching drop
      assert length(search_results) == 1
      assert hd(search_results).title == "Phoenix Tutorial"

      # Test that both drops exist without search
      all_drops = Drops.list_drops(%{user_id: user.id}, %{})
      assert length(all_drops) == 2
    end
  end
end
