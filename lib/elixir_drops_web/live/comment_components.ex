defmodule ElixirDropsWeb.CommentComponents do
  @moduledoc false

  use ElixirDropsWeb, :html

  alias ElixirDrops.Comments
  alias ElixirDrops.Comments.Comment
  alias ElixirDropsWeb.Comment.CommentFormComponent
  alias ElixirDropsWeb.DropComponents

  @type assigns() :: map()
  @type rendered() :: Phoenix.LiveView.Rendered.t()

  attr :comment_count, :integer, required: true
  attr :comment_form, Phoenix.HTML.Form, required: true
  attr :comment_offset, :integer, required: true
  attr :comments, :any, required: true
  attr :current_url, :string, required: true
  attr :current_user, :any, required: true
  attr :delete_comment_id, :string, default: nil
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
          <.comment_form
            form={@new_comment_form}
            comment_type={:comment}
            id="comment-form"
            field_id="comment-form-field"
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
      <div id="comments" phx-update="stream" class="space-y-6 last:mb-10">
        <div :for={{dom_id, comment} <- @comments} id={dom_id} class="border-b border-gray-200 p-4">
          <.comment
            comment_type={:comment}
            comment={comment}
            current_user={@current_user}
            current_url={@current_url}
            parent={nil}
            delete_comment_id={@delete_comment_id}
            comment_form={@comment_form}
            reply_form={@reply_form}
            depth={0}
          />
        </div>
      </div>
      <div class="flex flex-col items-center mx-auto mt-4 mb-8">
        <button
          class={[
            "text-[#2F19EE] text-sm px-4 py-2 border border-[#2F19EE] rounded-md hover:opacity-70",
            !(@top_level_comment_count >= @comment_offset) && "hidden"
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
    </div>
    """
  end

  attr :class, :string, default: nil
  attr :comment, :any, default: nil
  attr :comment_type, :atom
  attr :field_id, :string, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :id, :string, required: true
  attr :parent, :any, default: nil

  defp comment_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id={@id}
      phx-submit={
        if @comment do
          JS.push("update_comment", value: %{comment_id: @comment.id})
        else
          JS.push("new_comment",
            value: %{
              comment_type: @comment_type,
              parent_id: (@comment_type == :response && @parent.id) || "nil"
            }
          )
        end
      }
      phx-change={if @comment_type == :comment, do: "validate_comment", else: "validate_reply"}
      phx-click-away={
        if @comment_type == :response,
          do: JS.hide(to: "#reply-form-#{@parent.id}-depth-#{Map.get(assigns, :depth, 0)}")
      }
      class={@class}
      phx-hook="CommentForm"
    >
      <input :if={@comment_type == :response} type="hidden" name="parent_id" value={@parent.id} />
      <input
        :if={@comment && @comment_type == :comment}
        type="hidden"
        name="comment_id"
        value={@comment.id}
      />
      <input :if={!@comment && @comment_type == :comment} type="hidden" name="comment_id" value="nil" />
      <input type="hidden" name="form_id" value={@id} />
      <div class="group">
        <.custom_input
          id={@field_id}
          class={[
            "border-[1px] border-gray-200 focus-within:border-[#2F19EE] px-2 py-3 ",
            "rounded-lg transition-colors duration-100"
          ]}
          input_field_class={[
            "border-0 py-0 block w-full rounded-lg min-h-[2rem] ",
            "text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
            "placeholder:italic placeholder:text-gray-400"
          ]}
          field={@form[:body]}
          type="textarea"
          placeholder={
            if @comment_type == :comment,
              do: "What are your thoughts?",
              else: "Replying to #{@parent.user.name}"
          }
          aria-label={if @comment_type == :comment, do: "Add a comment", else: "Add a reply"}
          phx-debounce="100"
        >
          <:extra_content>
            <div class="justify-end gap-x-4 mt-3 flex opacity-0 pointer-events-none group-focus-within:opacity-100 group-focus-within:pointer-events-auto group-hover:pointer-events-auto">
              <button
                phx-click={if @comment_type == :comment, do: "cancel", else: "cancel_reply"}
                type="button"
                class="hover:opacity-80"
              >
                Cancel
              </button>
              <button
                class="bg-blue-500 text-white text-sm px-4 py-2 rounded-md hover:opacity-70"
                type="submit"
              >
                <span :if={!@comment && @comment_type == :comment}>Comment</span>
                <span :if={!@comment && @comment_type == :response}>Reply</span>
                <span :if={@comment}>Save</span>
              </button>
            </div>
          </:extra_content>
        </.custom_input>
      </div>

      <div class="text-xs text-gray-500 flex justify-between items-center mt-2">
        <p>Supports basic Markdown: **bold**, *italic*, and [links](url).</p>
        <p>
          Max 1000 characters
          (<span id={"#{@id}-char-count"}>0</span>/1000)
        </p>
      </div>
    </.form>
    """
  end

  attr :comment, Comment, required: true
  attr :comment_form, Phoenix.HTML.Form, required: true
  attr :comment_type, :atom
  attr :current_url, :string, required: true
  attr :current_user, :any, required: true
  attr :delete_comment_id, :string, default: nil
  attr :depth, :integer, default: 0
  attr :parent, :any, default: nil
  attr :reply_form, Phoenix.HTML.Form, required: true

  defp comment(assigns) do
    ~H"""
    <div class="comment font-roboto">
      <.comment_header
        comment={@comment}
        current_user={@current_user}
        current_url={@current_url}
        delete_comment_id={@delete_comment_id}
        depth={@depth}
      />
      <.comment_body
        comment_type={@comment_type}
        comment={@comment}
        parent={@parent}
        depth={@depth}
        form={@comment_form}
        current_user={@current_user}
      />
      <.comment_actions
        comment={@comment}
        current_user={@current_user}
        reply_form={@reply_form}
        depth={@depth}
      />

      <div
        class={[
          @depth == 0 && "hidden",
          "block"
        ]}
        id={"comment-replies-#{@comment.id}"}
      >
        <.comment_replies
          comment={@comment}
          current_user={@current_user}
          current_url={@current_url}
          comment_form={@comment_form}
          reply_form={@reply_form}
          depth={@depth}
          delete_comment_id={@delete_comment_id}
        />
      </div>
    </div>
    """
  end

  attr :comment, Comment, required: true
  attr :current_url, :string, required: true
  attr :current_user, :any, required: true
  attr :delete_comment_id, :string, default: nil
  attr :depth, :integer, default: 0

  defp comment_header(assigns) do
    depth = Map.get(assigns, :depth, 0)
    assigns = assign(assigns, :depth, depth)

    ~H"""
    <div class="comment-header relative">
      <div class="flex items-center gap-x-2 md:gap-x-3 text-xs md:text-sm">
        <img
          src={@comment.user.avatar || "/images/default-avatar.svg"}
          alt={@comment.user.name}
          class="w-8 h-8 rounded-full border border-gray-200 flex-shrink-0"
        />
        <p
          class="font-medium text-gray-900 max-w-[10ch] md:max-w-[100%] truncate"
          title={@comment.user.name}
        >
          {@comment.user.name}
        </p>
        <p class="text-gray-500 flex items-center gap-x-2">
          <span class="inline-block w-1 h-1 rounded-full bg-gray-500"></span>
          <svg
            :if={@comment.parent_id}
            width="20"
            height="20"
            viewBox="0 0 20 20"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              fill-rule="evenodd"
              clip-rule="evenodd"
              d="M7.70711 3.29289C8.09763 3.68342 8.09763 4.31658 7.70711 4.70711L5.41421 7H11C14.866 7 18 10.134 18 14V16C18 16.5523 17.5523 17 17 17C16.4477 17 16 16.5523 16 16V14C16 11.2386 13.7614 9 11 9H5.41421L7.70711 11.2929C8.09763 11.6834 8.09763 12.3166 7.70711 12.7071C7.31658 13.0976 6.68342 13.0976 6.29289 12.7071L2.29289 8.70711C1.90237 8.31658 1.90237 7.68342 2.29289 7.29289L6.29289 3.29289C6.68342 2.90237 7.31658 2.90237 7.70711 3.29289Z"
              fill="#8e8e8e"
            />
          </svg>
          <span
            :if={@comment.parent_id}
            class="max-w-[10ch] md:max-w-[100%] truncate"
            title={@comment.parent.user.name}
          >
            {@comment.parent.user.name}
            {if @comment.parent.deleted_at, do: " (Deleted Comment)"}
          </span>
          <span class="text-sm">{Timex.format!(@comment.inserted_at, "{relative}", :relative)}</span>
          <span
            :if={@current_user && @current_user.id == @comment.user_id && !@comment.parent_id}
            class="bg-[#eeeeee] text-[#575757] text-xs inline-block px-2 py-1 rounded-md"
          >
            You
          </span>
        </p>

        <button
          :if={@current_user && @current_user.id == @comment.user_id}
          class="ml-auto"
          aria-label="Toggle comment actions"
          phx-click={JS.toggle(to: "#comment-actions-#{@comment.id}-depth-#{@depth}")}
        >
          <.icon name="hero-ellipsis-vertical" class="w-4 h-4" />
        </button>
      </div>

      <div
        :if={@current_user && @current_user.id == @comment.user_id}
        id={"comment-actions-#{@comment.id}-depth-#{@depth}"}
        class={[
          "grid items-center absolute top-8 right-4 z-10",
          "bg-white p-4 rounded-md shadow-md border-[.2px] border-gray-200 md:w-[30%] hidden"
        ]}
        phx-click-away={JS.hide(to: "#comment-actions-#{@comment.id}-depth-#{@depth}")}
      >
        <button
          class="flex items-center gap-x-2 mb-6"
          phx-click={JS.push("update_comment_form", value: %{comment_id: @comment.id})}
        >
          <.icon name="hero-pencil" class="w-4 h-4" /> Edit comment
        </button>

        <button
          class="text-red-600 flex items-center gap-x-2"
          phx-click={JS.patch("#{@current_url}?delete_comment_id=#{@comment.id}")}
          type="button"
        >
          <.icon name="hero-trash" class="w-4 h-4" /> Delete comment
        </button>
      </div>

      <div
        :if={@delete_comment_id == to_string(@comment.id)}
        id={"delete-comment-modal-#{@comment.id}"}
      >
        <.modal
          id={"delete-comment-modal-#{@comment.id}-modal"}
          show
          on_cancel={JS.patch(@current_url)}
        >
          <.live_component
            module={CommentFormComponent}
            id={"delete-modal-#{@comment.id}"}
            comment={@comment}
            patch={@current_url}
          />
        </.modal>
      </div>
    </div>
    """
  end

  defp comment_body(assigns) do
    depth = Map.get(assigns, :depth, 0)
    assigns = assign(assigns, :depth, depth)

    ~H"""
    <div
      class="comment-body text-[.9rem] md:text-base/8 text-[#575757] leading-8 prose mt-2 break-words prose-pre:overflow-x-auto"
      id={"comment-body-#{@comment.id}-depth-#{@depth}"}
      phx-hook="DropBodyContainer"
    >
      <div :if={!@comment.deleted_at}>
        {DropComponents.to_html(@comment.body)}
        <DropComponents.copy_prompt />
      </div>
      <div :if={@comment.deleted_at}>
        [deleted]
      </div>
    </div>
    <div :if={!@comment.deleted_at} id={"edit-comment-container-#{@comment.id}"} class="hidden">
      <.comment_form
        form={@form}
        comment_type={@comment_type}
        comment={@comment}
        parent={@parent}
        id={"edit-comment-form-#{@comment.id}"}
        field_id="edit-comment-form-field"
      />
    </div>
    """
  end

  attr :comment, Comment, required: true
  attr :current_user, :any, required: true
  attr :depth, :integer, default: 10
  attr :parent, :any, default: nil
  attr :reply_form, Phoenix.HTML.Form, required: true

  defp comment_actions(assigns) do
    ~H"""
    <div class="comment-actions mt-4">
      <div class="flex items-center gap-x-6 text-xs md:text-sm text-gray-500 mb-4">
        <button
          :if={@depth == 0 && Enum.count(@comment.replies) > 0}
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
              {if Enum.count(@comment.replies) == 1, do: "reply", else: "replies"}
            </span>
          </div>
        </button>
        <button
          :if={@current_user && is_nil(@comment.parent_id)}
          phx-click={JS.toggle(to: "#reply-form-#{@comment.id}-depth-#{@depth}")}
        >
          Reply
        </button>
      </div>
      <.comment_form
        id={"reply-form-#{@comment.id}-depth-#{@depth}"}
        form={@reply_form}
        comment_type={:response}
        comment={nil}
        parent={@comment}
        class="hidden"
        field_id={"reply-form-field-#{@comment.id}-depth-#{@depth}"}
      />
    </div>
    """
  end

  attr :comment, Comment, required: true
  attr :comment_form, Phoenix.HTML.Form, required: true
  attr :current_url, :string, required: true
  attr :current_user, :any, required: true
  attr :delete_comment_id, :string, default: nil
  attr :depth, :integer
  attr :reply_form, Phoenix.HTML.Form, required: true

  defp comment_replies(assigns) do
    ~H"""
    <div
      :if={@comment.replies && Enum.any?(@comment.replies)}
      class="mt-4"
      id={"replies-#{@comment.id}-depth-#{@depth}"}
    >
      <div :for={reply <- @comment.replies} class="ml-6 md:ml-10 space-y-4 pl-4">
        <.comment
          comment={reply}
          comment_type={:response}
          current_user={@current_user}
          current_url={@current_url}
          delete_comment_id={@delete_comment_id}
          comment_form={@comment_form}
          reply_form={@reply_form}
          parent={Comments.get_comment!(reply.parent_id)}
          depth={@depth + 1}
        />
      </div>
    </div>
    """
  end
end
