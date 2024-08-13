defmodule ElixirDropsWeb.SeoLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDropsWeb.DropLive.DropComponents

  @image_regex ~r/(?<alt>!\[[^\]]*\])\((?<filename>.*?)(?=\"|\))\)/

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:code_block, nil)
      |> assign(:is_image?, false),
      layout: false
    }
  end

  @impl Phoenix.LiveView
  def handle_params(%{"code_block" => code_block}, _uri, socket) do
    {:noreply,
     socket
     |> assign(:code_block, code_block)
     |> assign(:is_image?, Regex.match?(@image_regex, code_block))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <section class={[
      !@is_image? &&
        "min-h-[100vh] flex items-center justify-center bg-gradient-to-r from-[#4c3ddb] via-[#6159be] to-[#818494]",
      @is_image? && "min-h-[100vh]"
    ]}>
      <div class={[
        "rounded-xl overflow-hidden seo-image flex items-center justify-center",
        @is_image? && "w-full h-full"
      ]}>
        <%= @code_block && DropComponents.to_html(@code_block) %>
      </div>
    </section>
    """
  end
end
