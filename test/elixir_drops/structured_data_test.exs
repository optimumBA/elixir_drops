defmodule ElixirDrops.StructuredDataTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.StructuredData

  describe "generate_drop_json_ld/1" do
    setup do
      user = user_fixture()
      drop = drop_fixture(user)

      json_ld = StructuredData.generate_drop_json_ld(drop)
      decoded = Jason.decode!(json_ld)

      %{drop: drop, decoded: decoded}
    end

    test "generates valid JSON-LD for a drop", %{drop: drop, decoded: decoded} do
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
      assert is_list(decoded["keywords"])
    end

    test "handles special characters", %{drop: drop} do
      drop_with_special_chars =
        drop_fixture(%Drop{}, drop.user, %{
          title: "Special & Characters <in> Title",
          body: "Body with & special <characters> and \"quotes\""
        })

      json_ld = StructuredData.generate_drop_json_ld(drop_with_special_chars)
      decoded = Jason.decode!(json_ld)

      assert decoded["headline"] == "Special & Characters <in> Title"
      assert decoded["articleBody"] == "Body with & special <characters> and \"quotes\""
    end

    test "handles drops with code blocks in body", %{drop: drop} do
      drop_with_code_blocks =
        drop_fixture(%Drop{}, drop.user, %{
          body: """
          Here's some code:
          ```elixir
          defmodule MyModule do
            def hello do
              :world
            end
          end
          ```
          And some more text after the code block
          """
        })

      json_ld = StructuredData.generate_drop_json_ld(drop_with_code_blocks)
      decoded = Jason.decode!(json_ld)

      keywords = decoded["keywords"]
      refute "MyModule" in keywords
      refute "hello" in keywords
      assert "code" in keywords
      assert "block" in keywords
    end

    test "handles drops with screenshots", %{drop: drop} do
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

    test "extracts keywords from body and limits to 30 keywords", %{drop: drop} do
      drop_with_content =
        drop_fixture(%Drop{}, drop.user, %{
          body: """
          This is an example of using Phoenix LiveView for building interactive updates in your applications.
          ```elixir
          defmodule MyModule do
            def assigns do
              :assigns
            end
          end
          ```
          We are testing the keyword extraction functionality.
          The test should extract meaningful words like Elixir programming testing phx-change phx-submit handle_event assigns socket plug component livecomponent liveview etc.
          """
        })

      json_ld = StructuredData.generate_drop_json_ld(drop_with_content)
      json = Jason.decode!(json_ld)
      keywords = json["keywords"]

      assert length(keywords) <= 30
      assert "Phoenix" in keywords
      assert "LiveView" in keywords
      assert "assigns" in keywords
      assert "socket" in keywords
      assert "phx-submit" in keywords
      refute "this" in keywords
      refute "we" in keywords
      refute "defmodule" in keywords
      refute "MyModule" in keywords
    end
  end
end
