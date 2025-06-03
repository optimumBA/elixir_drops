defmodule ElixirDrops.StructuredDataTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.StructuredData

  describe "generate_drop_json_ld/1" do
    test "generates valid JSON-LD for a drop" do
      user = user_fixture()
      drop = drop_fixture(user)

      json_ld = StructuredData.generate_drop_json_ld(drop)
      decoded = Jason.decode!(json_ld)

      assert decoded["@context"] == "https://schema.org"
      assert decoded["@type"] == "Elixir Drop"
      assert decoded["headline"] == drop.title
      assert decoded["articleBody"] == drop.body
      assert decoded["url"] == "https://elixirdrops.net/d/#{drop.short_id}"

      assert decoded["author"]["@type"] == "Person"
      assert decoded["author"]["name"] == drop.user.name
      assert decoded["author"]["url"] == "https://github.com/#{drop.user.github_username}"
      assert decoded["author"]["image"] == drop.user.avatar

      assert decoded["publisher"]["@type"] == "Organization"
      assert decoded["publisher"]["name"] == "ElixirDrops"
      assert decoded["publisher"]["logo"]["@type"] == "ImageObject"
      assert decoded["publisher"]["logo"]["url"] == "https://elixirdrops.net/images/logo.png"

      assert decoded["datePublished"] == NaiveDateTime.to_iso8601(drop.inserted_at)
      assert decoded["dateModified"] == NaiveDateTime.to_iso8601(drop.updated_at)

      assert decoded["mainEntityOfPage"]["@type"] == "WebPage"
      assert decoded["mainEntityOfPage"]["@id"] == "https://elixirdrops.net/d/#{drop.short_id}"

      assert is_binary(decoded["description"])
      assert String.length(decoded["description"]) <= 160
      assert is_binary(decoded["keywords"])
    end

    test "generates JSON-LD that passes Google's Rich Results Test requirements" do
      user = user_fixture()
      drop = drop_fixture(user)

      json_ld = StructuredData.generate_drop_json_ld(drop)
      decoded = Jason.decode!(json_ld)

      assert decoded["@context"] == "https://schema.org"
      assert decoded["@type"] == "Elixir Drop"
      assert is_binary(decoded["headline"])
      assert is_binary(decoded["articleBody"])
      assert is_binary(decoded["url"])

      assert decoded["author"]["@type"] == "Person"
      assert is_binary(decoded["author"]["name"])
      assert is_binary(decoded["author"]["url"])
      assert is_binary(decoded["author"]["image"])

      assert decoded["publisher"]["@type"] == "Organization"
      assert is_binary(decoded["publisher"]["name"])
      assert decoded["publisher"]["logo"]["@type"] == "ImageObject"
      assert is_binary(decoded["publisher"]["logo"]["url"])

      assert is_binary(decoded["datePublished"])
      assert is_binary(decoded["dateModified"])
      assert {:ok, _} = NaiveDateTime.from_iso8601(decoded["datePublished"])
      assert {:ok, _} = NaiveDateTime.from_iso8601(decoded["dateModified"])

      assert String.starts_with?(decoded["url"], "https://")
      assert String.starts_with?(decoded["author"]["url"], "https://")
      assert String.starts_with?(decoded["publisher"]["logo"]["url"], "https://")
    end

    test "handles drops with special characters in title and body" do
      user = user_fixture()

      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Special & Characters <in> Title",
          body: "Body with & special <characters> and \"quotes\""
        })

      json_ld = StructuredData.generate_drop_json_ld(drop)
      decoded = Jason.decode!(json_ld)

      assert decoded["headline"] == "Special & Characters <in> Title"
      assert decoded["articleBody"] == "Body with & special <characters> and \"quotes\""
    end

    test "handles drops with code blocks in body" do
      user = user_fixture()

      drop =
        drop_fixture(%Drop{}, user, %{
          body: """
          Here's some code:
          ```elixir
          defmodule MyModule do
            def hello do
              :world
            end
          end
          ```
          """
        })

      json_ld = StructuredData.generate_drop_json_ld(drop)
      decoded = Jason.decode!(json_ld)

      assert String.contains?(decoded["articleBody"], "```elixir")
      assert String.contains?(decoded["articleBody"], "defmodule MyModule do")
      assert String.contains?(decoded["keywords"], "MyModule")
    end

    test "handles drops with screenshots" do
      user = user_fixture()
      drop = drop_fixture(user)

      drop_with_screenshot = %{
        drop
        | screenshot: %{
            internal_url: "https://example.com/internal.png",
            meta_url: "https://example.com/meta.png",
            status: :completed
          }
      }

      json_ld = StructuredData.generate_drop_json_ld(drop_with_screenshot)
      decoded = Jason.decode!(json_ld)

      assert length(decoded["image"]) == 1
      image = List.first(decoded["image"])
      assert image["@type"] == "ImageObject"
      assert image["url"] == "https://example.com/meta.png"
      assert image["width"] == "1200"
      assert image["height"] == "630"
    end
  end
end
