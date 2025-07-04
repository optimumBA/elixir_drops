defmodule ElixirDrops.Comments.MarkdownRendererTest do
  use ExUnit.Case, async: true

  alias ElixirDrops.Comments.MarkdownRenderer

  describe "render/1" do
    test "converts bold markdown" do
      result1 = MarkdownRenderer.render("**bold text**")
      assert result1 == "<strong>bold text</strong>"

      result2 = MarkdownRenderer.render("__bold text__")
      assert result2 == "<strong>bold text</strong>"
    end

    test "converts italic markdown" do
      result1 = MarkdownRenderer.render("*italic text*")
      assert result1 == "<em>italic text</em>"

      result2 = MarkdownRenderer.render("_italic text_")
      assert result2 == "<em>italic text</em>"
    end

    test "converts links" do
      result = MarkdownRenderer.render("[example](https://example.com)")

      assert result =~
               ~r/<a href="https:\/\/example\.com" target="_blank" rel="noopener noreferrer">example<\/a>/
    end

    test "converts newlines to br tags" do
      result = MarkdownRenderer.render("line 1\nline 2")
      assert result == "line 1<br>line 2"
    end

    test "handles mixed formatting" do
      result = MarkdownRenderer.render("**bold** and *italic* and [link](https://example.com)")

      assert result =~ "<strong>bold</strong>"
      assert result =~ "<em>italic</em>"
      assert result =~ ~r/<a href="https:\/\/example\.com"/
    end

    test "sanitizes unsafe HTML tags" do
      result = MarkdownRenderer.render("<script>alert('xss')</script>")
      refute result =~ "<script>"
      refute result =~ "alert"
    end

    test "preserves allowed HTML tags" do
      result = MarkdownRenderer.render("Keep <strong>this</strong> and <em>this</em>")
      assert result =~ "<strong>this</strong>"
      assert result =~ "<em>this</em>"
    end

    test "sanitizes unsafe links" do
      result = MarkdownRenderer.render("[bad link](javascript:alert('xss'))")
      assert result =~ ~r/<a href="#"/
      refute result =~ "javascript:"
    end

    test "allows safe HTTP and HTTPS links" do
      http_result = MarkdownRenderer.render("[http link](http://example.com)")
      https_result = MarkdownRenderer.render("[https link](https://example.com)")

      assert http_result =~ ~r/<a href="http:\/\/example\.com"/
      assert https_result =~ ~r/<a href="https:\/\/example\.com"/
    end
  end
end
