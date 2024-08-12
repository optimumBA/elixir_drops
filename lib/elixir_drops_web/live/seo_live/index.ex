defmodule ElixirDropsWeb.SeoLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDropsWeb.DropLive.DropComponents

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # code_block =
    #   # "```elixir\ndefmodule Face do\n    defstruct ~w[eyes legs ears]a\n\n@image_regex ~r/(?<alt>!\\[[^\\]]*\\])\\((?<filename>.*?)(?=\\\"|\\))\\)/\n  @markdown_regex ~r/```[a-z]*\\n[\\s\\S]*?\\n```/\n\n  @spec create_drop_meta_image(drop()) :: image_url() | nil\n  def create_drop_meta_image(drop) do\n    %Drop{body: body} = drop\n\n    body\n    |> get_first_code_block()\n    |> maybe_get_first_image_or_return_code_block(drop) |> IO.inspect()\n    # |> get_image_url(drop)\n  end\n\n  defp get_first_code_block(body), do: Regex.run(@markdown_regex, body, capture: :first)\n\n  defp maybe_get_first_image_or_return_code_block(nil, drop),\n    do: Regex.run(@image_regex, drop.body, capture: :first)\n\n  defp maybe_get_first_image_or_return_code_block(code_block, _drop), do: code_block\nend\n```"
    #   "![A sky with stars](https://images.unsplash.com/photo-1721332149371-fa99da451baa?w=800&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDF8MHxmZWF0dXJlZC1waG90b3MtZmVlZHwxfHx8ZW58MHx8fHx8)"

    {:ok, assign(socket, :code_block, nil), layout: false}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"code_block" => code_block}, _uri, socket) do
    {:noreply, assign(socket, :code_block, code_block)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <section class="bg-gradient-to-r from-[#4c3ddb] via-[#6159be] to-[#818494] min-h-[100vh] flex items-center justify-center">
      <div class="rounded-xl overflow-hidden seo-image">
        <%= @code_block && DropComponents.to_html(@code_block) %>
      </div>
    </section>
    """
  end
end
