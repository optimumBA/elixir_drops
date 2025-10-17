defmodule ElixirDropsWeb.Comment.CommentFormComponent do
  @moduledoc false
  use ElixirDropsWeb, :live_component

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 roboto-medium">
      <section class="text-[#252525] text-2xl">Delete Comment</section>
      <section class="roboto-regular">Are you sure you want to delete this comment?</section>
      <section class="flex gap-4 justify-end mt-4">
        <button
          class="w-24 h-12 flex justify-center items-center rounded-lg mb-6 text-[#4F4F4F] bg-[#EEEEEE]"
          phx-click={JS.exec("data-cancel", to: "#delete-comment-modal-#{@comment.id}-modal")}
        >
          Cancel
        </button>
        <button
          id={"confirm-comment-deletion-#{@comment.id}"}
          class="w-24 h-12 flex justify-center items-center rounded-lg mb-6 text-[#EAE8FD] bg-[#2F19EE]"
          phx-click={
            hide_modal("delete-comment-modal-#{@comment.id}-modal")
            |> JS.push("delete_comment", value: %{comment_id: @comment.id, patch_url: @patch})
          }
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
