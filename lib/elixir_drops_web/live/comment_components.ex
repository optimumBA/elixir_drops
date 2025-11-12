defmodule ElixirDropsWeb.CommentComponents do
  @moduledoc false

  use ElixirDropsWeb, :html

  alias ElixirDrops.Comments.Comment
  alias ElixirDropsWeb.Comment.FormComponent
  alias ElixirDropsWeb.DropComponents

  @type assigns() :: map()
  @type rendered() :: Phoenix.LiveView.Rendered.t()

  attr :comment_count, :integer, required: true
  attr :comment_form, Phoenix.HTML.Form, required: true
  attr :comment_pending_deletion, Comment, default: nil
  attr :comment_offset, :integer, required: true
  attr :comments, :any, required: true
  attr :current_url, :string, required: true
  attr :current_user, :any, required: true
  attr :new_comment_form, Phoenix.HTML.Form, required: true
  attr :reply_form, Phoenix.HTML.Form, required: true
  attr :top_level_comment_count, :integer, required: true

  @spec comment_section(assigns()) :: rendered()
  def comment_section(assigns) do
    ~H"""
    <div>
      <div class="comments-section mt-8 border-y py-8">
        <h3 class="text-lg font-semibold mb-6 text-gray-700">
          Comments ({@comment_count})
        </h3>
        <div :if={@current_user}>
          <.live_component
            class=""
            comment={nil}
            comment_id={nil}
            comment_type={:comment}
            field_id="comment-form-field"
            form={@new_comment_form}
            parent={nil}
            parent_id={nil}
            id="new-comment-form"
            module={FormComponent}
          />
        </div>
        <div :if={!@current_user}>
          <p class="text-gray-600 text-center text-sm bg-[#EAE8FD80] py-4 rounded-lg">
            <.link
              href={~p"/auth/github" <> "?return_to=#{assigns[:current_url] || "/"}"}
              class="text-indigo-600 hover:opacity-80 font-medium"
            >
              Sign in with GitHub
            </.link>
            to join the discussion
          </p>
        </div>
      </div>
      <div id="comments" phx-update="stream" class="last:mb-10">
        <div :for={{dom_id, comment} <- @comments} id={dom_id} class="border-b border-gray-200 py-2">
          <.comment
            comment={comment}
            comment_form={@comment_form}
            comment_type={:comment}
            current_url={@current_url}
            current_user={@current_user}
            depth={0}
            parent={nil}
            reply_form={@reply_form}
          />
        </div>
      </div>
      <div class="flex flex-col items-center mx-auto mt-4 mb-8">
        <button
          class={[
            "text-[#2F19EE] text-sm px-4 py-2 border border-[#2F19EE] rounded-md hover:opacity-70",
            @top_level_comment_count <= @comment_offset && "hidden"
          ]}
          type="button"
          phx-click={
            JS.push("load_more",
              value: %{offset: @comment_offset}
            )
          }
        >
          See more responses
        </button>
      </div>
      <div :if={@comment_pending_deletion}>
        <.modal
          id={"delete-comment-modal-#{@comment_pending_deletion.id}"}
          show
          on_cancel={JS.push("cancel_comment_deletion")}
        >
          <.delete_comment_component comment={@comment_pending_deletion} />
        </.modal>
      </div>
    </div>
    """
  end

  attr :comment, Comment, required: true
  attr :comment_form, Phoenix.HTML.Form, required: true
  attr :comment_type, :atom
  attr :current_url, :string, required: true
  attr :current_user, :any, required: true
  attr :depth, :integer, required: true
  attr :parent, :any, default: nil
  attr :reply_form, Phoenix.HTML.Form, required: true

  defp comment(assigns) do
    ~H"""
    <div class="flex gap-4 comment font-roboto" id={"comment-container-#{@comment.id}"}>
      <div class="shrink-0">
        <img
          src={@comment.user.avatar || "/images/default-avatar.svg"}
          alt={@comment.user.name}
          class="w-11 h-11 rounded-full border border-gray-200 flex-shrink-0"
        />
      </div>
      <div class="grow min-w-0">
        <.comment_header comment={@comment} current_url={@current_url} current_user={@current_user} />
        <.comment_body comment={@comment} />
        <.comment_actions
          comment={@comment}
          comment_type={@comment_type}
          current_user={@current_user}
          form={@comment_form}
          parent={@parent}
          reply_form={@reply_form}
        />

        <div
          class={[
            "hidden"
          ]}
          id={"comment-replies-#{@comment.id}"}
        >
          <.comment_replies
            comment={@comment}
            comment_form={@comment_form}
            current_url={@current_url}
            current_user={@current_user}
            depth={@depth}
            reply_form={@reply_form}
          />
        </div>
      </div>
    </div>
    """
  end

  attr :comment, Comment, required: true
  attr :current_url, :string, required: true
  attr :current_user, :any, required: true

  defp comment_header(assigns) do
    ~H"""
    <div class="comment-header relative mt-3">
      <div class="flex items-center gap-x-2 md:gap-x-3 text-xs md:text-sm">
        <p
          class="font-medium text-gray-900 max-w-[10ch] md:max-w-[100%] truncate"
          title={@comment.user.name}
        >
          {@comment.user.name}
        </p>
        <p class="text-[#8E8E8E] roboto-regular flex items-center gap-x-2">
          <span class="hidden sm:inline-block w-1 h-1 rounded-full bg-gray-500"></span>
          <span class="text-sm">{Timex.format!(@comment.inserted_at, "{relative}", :relative)}</span>
          <span
            :if={@current_user && @current_user.id == @comment.user_id && !@comment.parent_id}
            class="bg-[#eeeeee] text-[#575757] text-xs inline-block px-2 py-1 rounded-md"
          >
            You
          </span>
          <span
            :if={@comment.edited_at}
            class="hidden sm:inline-block w-1 h-1 rounded-full bg-gray-500"
          >
          </span>
          <span :if={@comment.edited_at} class="hidden sm:inline-block text-xs py-1 italic">
            Edited
          </span>
        </p>

        <button
          :if={@current_user && @current_user.id == @comment.user_id}
          class="ml-auto"
          aria-label="Toggle comment actions"
          phx-click={JS.toggle(to: "#comment-actions-#{@comment.id}")}
        >
          <.icon name="hero-ellipsis-horizontal" class="w-4 h-4" />
        </button>
      </div>

      <div
        id={"comment-actions-#{@comment.id}"}
        class={[
          "grid items-center absolute top-8 right-4 z-10",
          "bg-white p-4 rounded-md shadow-md border-[.2px] border-gray-200 md:w-[30%] hidden"
        ]}
        phx-click-away={JS.hide(to: "#comment-actions-#{@comment.id}")}
      >
        <button
          id={"trigger-comment-edit-#{@comment.id}"}
          class="flex items-center gap-x-2 mb-6"
          phx-click={
            JS.toggle(to: "#comment-actions-#{@comment.id}")
            |> JS.push("change_edit_comment_form", value: %{comment_id: @comment.id})
          }
        >
          <.icon name="hero-pencil" class="w-4 h-4" /> Edit comment
        </button>

        <button
          id={"trigger-comment-deletion-#{@comment.id}"}
          class="text-red-600 flex items-center gap-x-2"
          phx-click={
            JS.toggle(to: "#comment-actions-#{@comment.id}")
            |> JS.push("assign_comment_id_to_be_deleted",
              value: %{comment_pending_deletion_id: @comment.id}
            )
          }
          type="button"
        >
          <.icon name="hero-trash" class="w-4 h-4" /> Delete comment
        </button>
      </div>
    </div>
    """
  end

  defp comment_body(assigns) do
    ~H"""
    <div
      class="comment-body text-[.9rem] md:text-base/8 text-[#575757] leading-8 prose my-2 break-words prose-pre:overflow-x-auto"
      id={"comment-body-#{@comment.id}"}
      phx-hook="DropBodyContainer"
    >
      <div>
        {DropComponents.to_html(@comment.body)}
        <DropComponents.copy_prompt />
      </div>
    </div>
    """
  end

  attr :comment, Comment, required: true
  attr :comment_type, :atom
  attr :current_user, :any, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :parent, :any, default: nil
  attr :reply_form, Phoenix.HTML.Form, required: true

  defp comment_actions(assigns) do
    ~H"""
    <div class="comment-actions">
      <div class="flex items-center gap-x-6 text-xs md:text-sm text-gray-500 mb-4">
        <button
          :if={Enum.count(@comment.replies) > 0}
          class="flex items-center gap-2"
          phx-click={
            JS.toggle(to: "#comment-replies-#{@comment.id}")
            |> JS.toggle(to: "#comment-replies-count-#{@comment.id}", display: "inline-block")
            |> JS.toggle(to: "#hide-text-#{@comment.id}", display: "inline-block")
          }
        >
          <div class="w-5 h-5 md:w-6 md:h-6">
            <.icon name="hero-chat-bubble-oval-left-ellipsis" class="w-full h-full object-cover" />
          </div>

          <div>
            <span id={"comment-replies-count-#{@comment.id}"}>
              {Enum.count(@comment.replies)}
            </span>
            <span id={"hide-text-#{@comment.id}"} class="hidden">Hide</span>
            <span>
              {if Enum.count(@comment.replies) < 2, do: "reply", else: "replies"}
            </span>
          </div>
        </button>
        <button
          :if={@current_user && is_nil(@comment.parent_id)}
          id={"reply-to-comment-button-#{@comment.id}"}
          phx-click={
            JS.toggle(to: "#reply-form-#{@comment.id}")
            |> JS.focus(to: "#reply-form-field-#{@comment.id}")
          }
        >
          Reply
        </button>
      </div>
      <.live_component
        class="hidden"
        comment={nil}
        comment_id={nil}
        comment_type={:response}
        form={@reply_form}
        field_id={"reply-form-field-#{@comment.id}"}
        id={"reply-form-#{@comment.id}"}
        parent={@comment}
        parent_id={@comment.id}
        module={FormComponent}
      />

      <.live_component
        class="hidden"
        comment={@comment}
        comment_id={@comment.id}
        comment_type={@comment_type}
        form={@form}
        field_id={"edit-comment-form-field-#{@comment.id}"}
        id={"edit-comment-form-#{@comment.id}"}
        parent={@parent}
        parent_id={if @parent, do: @parent.id, else: nil}
        module={FormComponent}
      />
    </div>
    """
  end

  attr :comment, Comment, required: true
  attr :comment_form, Phoenix.HTML.Form, required: true
  attr :current_url, :string, required: true
  attr :current_user, :any, required: true
  attr :depth, :integer, required: true
  attr :reply_form, Phoenix.HTML.Form, required: true

  defp comment_replies(assigns) do
    ~H"""
    <div
      :if={@comment.replies && Enum.any?(@comment.replies)}
      id={"replies-#{@comment.id}-depth-#{@depth}"}
    >
      <div :for={reply <- @comment.replies}>
        <.comment
          comment={reply}
          comment_form={@comment_form}
          comment_type={:response}
          current_url={@current_url}
          current_user={@current_user}
          depth={@depth + 1}
          parent={@comment}
          reply_form={@reply_form}
        />
      </div>
    </div>
    """
  end

  defp delete_comment_component(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 roboto-medium">
      <section class="text-[#252525] text-2xl">Delete Comment</section>
      <section class="roboto-regular">Are you sure you want to delete this comment?</section>
      <section class="flex gap-4 justify-end mt-4">
        <button
          class="w-24 h-12 flex justify-center items-center rounded-lg mb-6 text-[#4F4F4F] bg-[#EEEEEE]"
          phx-click={JS.exec("data-cancel", to: "#delete-comment-modal-#{@comment.id}")}
        >
          Cancel
        </button>
        <button
          id={"confirm-comment-deletion-#{@comment.id}"}
          class="w-24 h-12 flex justify-center items-center rounded-lg mb-6 text-[#EAE8FD] bg-[#2F19EE]"
          phx-click={
            hide_modal("delete-comment-modal-#{@comment.id}")
            |> JS.push("delete_comment", value: %{comment_id: @comment.id})
          }
        >
          Confirm
        </button>
      </section>
    </div>
    """
  end
end
