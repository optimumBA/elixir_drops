defmodule ElixirDropsWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use ElixirDropsWeb, :html

  # Templates in error_html/ (404.html.heex) are complete HTML documents, because
  # error rendering runs with layout: false. Any other template, such as
  # "500.html", falls back to the plain text status message below.
  embed_templates "error_html/*"

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
