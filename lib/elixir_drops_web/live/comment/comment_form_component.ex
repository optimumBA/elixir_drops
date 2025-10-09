defmodule ElixirDropsWeb.Comment.CommentFormComponent do
  @moduledoc false
  use ElixirDropsWeb, :live_component

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <section class="font-bold">Delete Comment</section>
      <section>Are you sure you want to delete this comment?</section>
      <section class="flex gap-4 justify-end">
        <button
          class="flex items-center gap-x-2 rounded-lg mb-6 px-6 py-4 bg-[#EEEEEE]"
          phx-click={JS.patch(@patch)}
        >
          Cancel
        </button>
        <button
          class="flex items-center gap-x-2 mb-6 text-[#EAE8FD] px-6 py-4 rounded-lg bg-[#2F19EE]"
          phx-click={JS.push("delete_comment", value: %{comment_id: @comment.id, patch_url: @patch})}
        >
          Confirm
        </button>
      </section>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end
end
