defmodule ElixirDrops.MarkdownFormatterTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.MarkdownFormatter
  alias ElixirDropsWeb.Endpoint

  describe "format_drop/1" do
    test "formats drop as markdown with title, body, and metadata" do
      user = user_fixture(%{github_username: "testuser"})

      drop =
        drop_fixture(%Drop{}, user, %{
          title: "My Drop Title",
          body: "This is the drop content"
        })

      markdown = MarkdownFormatter.format_drop(drop)

      assert markdown =~ "# My Drop Title"
      assert markdown =~ "This is the drop content"
      assert markdown =~ "Created by: testuser"
      assert markdown =~ drop.short_id
      assert markdown =~ "---"
      assert markdown =~ "Date:"
      assert markdown =~ "URL:"
    end

    test "includes proper URL format in markdown" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user, %{title: "URL Test", body: "Testing URLs"})

      markdown = MarkdownFormatter.format_drop(drop)

      assert markdown =~ "URL: #{Endpoint.url()}/d/#{drop.short_id}"
    end

    test "formats date correctly" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user, %{title: "Date Test", body: "Testing dates"})

      markdown = MarkdownFormatter.format_drop(drop)

      # Check that date is formatted as "Month Day, Year"
      assert markdown =~ ~r/Date: \w+ \d{1,2}, \d{4}/
    end

    test "handles special characters in title and body" do
      user = user_fixture(%{github_username: "special_user"})

      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Title with # and * chars",
          body: "Body with **bold** and _italic_ markdown"
        })

      markdown = MarkdownFormatter.format_drop(drop)

      assert markdown =~ "# Title with # and * chars"
      assert markdown =~ "Body with **bold** and _italic_ markdown"
      assert markdown =~ "Created by: special_user"
    end
  end

  describe "format_index/1" do
    test "formats drops list as markdown index" do
      user = user_fixture()
      drop1 = drop_fixture(%Drop{}, user, %{title: "Drop 1", body: "First drop content"})
      drop2 = drop_fixture(%Drop{}, user, %{title: "Drop 2", body: "Second drop content"})

      index = MarkdownFormatter.format_index([drop1, drop2])

      assert index =~ "# ElixirDrops Index"
      assert index =~ "A collection of Elixir tips, tricks, and code snippets"
      assert index =~ "## [Drop 1]"
      assert index =~ "## [Drop 2]"
      assert index =~ drop1.short_id
      assert index =~ drop2.short_id
    end

    test "includes proper structure with header and separation" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user, %{title: "Test Drop", body: "Test content"})

      index = MarkdownFormatter.format_index([drop])

      assert index =~ "# ElixirDrops Index"
      assert index =~ "---"
      assert index =~ "## [Test Drop]"
    end

    test "extracts proper descriptions from drop bodies" do
      user = user_fixture(%{github_username: "desc_user"})

      # Test various body formats
      drop1 =
        drop_fixture(%Drop{}, user, %{
          title: "Simple Drop",
          body: "This is a simple description.\nMore content here."
        })

      drop2 =
        drop_fixture(%Drop{}, user, %{
          title: "Header Drop",
          body: "# Title\n\nThis should be the description.\nMore content."
        })

      drop3 =
        drop_fixture(%Drop{}, user, %{
          title: "Empty Lines Drop",
          body: "\n\nActual content after empty lines.\nMore stuff."
        })

      index = MarkdownFormatter.format_index([drop1, drop2, drop3])

      assert index =~ "This is a simple description."
      assert index =~ "This should be the description."
      assert index =~ "Actual content after empty lines."
    end

    test "handles long descriptions by truncating" do
      user = user_fixture()

      long_body =
        String.duplicate("This is a very long description that should be truncated. ", 10)

      drop = drop_fixture(%Drop{}, user, %{title: "Long Drop", body: long_body})

      index = MarkdownFormatter.format_index([drop])

      # Should be truncated
      assert index =~ "..."
      # Should be significantly shorter
      assert String.length(index) < String.length(long_body) + 1000
    end

    test "handles drops with no readable description" do
      user = user_fixture()

      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Header Only",
          body: "# Header 1\n## Header 2\n### Header 3"
        })

      index = MarkdownFormatter.format_index([drop])

      assert index =~ "No description available"
    end

    test "includes author and date information for each drop" do
      user = user_fixture(%{github_username: "author_test"})
      drop = drop_fixture(%Drop{}, user, %{title: "Author Test", body: "Content"})

      index = MarkdownFormatter.format_index([drop])

      assert index =~ "Author: author_test"
      assert index =~ "Created:"
      # Verify that redundant links are not present
      refute index =~ "[View Drop]"
      refute index =~ "[Raw Markdown]"
    end

    test "generates correct URLs for drops" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user, %{title: "URL Test", body: "URL testing"})

      index = MarkdownFormatter.format_index([drop])

      assert index =~ "](#{Endpoint.url()}/d/#{drop.short_id}.md)"
    end

    test "returns proper header for empty list" do
      index = MarkdownFormatter.format_index([])

      assert index =~ "# ElixirDrops Index"
      assert index =~ "A collection of Elixir tips, tricks, and code snippets"
      assert index =~ "---"
      # Should not contain any drop entries
      refute index =~ "## ["
    end
  end
end
