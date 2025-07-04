defmodule ElixirDrops.Comments.MarkdownRenderer do
  @moduledoc """
  Safe markdown rendering for comments.
  Only allows: bold, italic, and links.
  """

  @spec render(String.t()) :: String.t()
  def render(markdown) do
    markdown
    |> convert_markdown_to_html()
    |> sanitize_html()
  end

  defp convert_markdown_to_html(markdown) do
    # Simple markdown conversion for basic formatting
    markdown
    |> convert_bold()
    |> convert_italic()
    |> convert_links()
    |> convert_newlines()
  end

  defp convert_bold(text) do
    text
    |> String.replace(~r/\*\*([^*]+)\*\*/, "<strong>\\1</strong>")
    |> String.replace(~r/__([^_]+)__/, "<strong>\\1</strong>")
  end

  defp convert_italic(text) do
    text
    |> String.replace(~r/\*([^*]+)\*/, "<em>\\1</em>")
    |> String.replace(~r/_([^_]+)_/, "<em>\\1</em>")
  end

  defp convert_links(text) do
    String.replace(
      text,
      ~r/\[([^\]]+)\]\(([^)]+)\)/,
      "<a href=\"\\2\" target=\"_blank\" rel=\"noopener noreferrer\">\\1</a>"
    )
  end

  defp convert_newlines(text) do
    String.replace(text, ~r/\n/, "<br>")
  end

  defp sanitize_html(html) do
    # Remove any HTML tags that aren't allowed (including their content for script tags)
    html
    |> String.replace(~r/<script[^>]*>.*?<\/script>/i, "")
    |> String.replace(~r/<(?!\/?(strong|em|a|br)(\s[^>]*)?>)[^>]*>/, "")
    |> sanitize_links()
  end

  defp sanitize_links(html) do
    # Ensure links have proper attributes and safe href
    Regex.replace(
      ~r/<a\s+href="([^"]*)"[^>]*>/,
      html,
      fn _match, href ->
        if safe_url?(href) do
          "<a href=\"#{href}\" target=\"_blank\" rel=\"noopener noreferrer\">"
        else
          "<a href=\"#\" target=\"_blank\" rel=\"noopener noreferrer\">"
        end
      end
    )
  end

  defp safe_url?(url) do
    # Only allow http/https URLs
    String.match?(url, ~r/^https?:\/\//)
  end
end
