defmodule ElixirDropsWeb.SeoLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDropsWeb.DropComponents

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :code_block, nil), layout: false}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"code_block" => code_block}, _uri, socket) do
    {:noreply, assign(socket, :code_block, code_block)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <section class="min-h-[100vh] flex items-center justify-center bg-gradient-to-r from-[#4c3ddb] via-[#6159be] to-[#818494]">
      <div class="rounded-xl overflow-hidden seo-image flex items-center justify-center">
        <%= @code_block && DropComponents.to_html(@code_block) %>
      </div>
    </section>
    """
  end
end
