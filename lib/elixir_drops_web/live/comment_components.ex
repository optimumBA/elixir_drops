defmodule ElixirDropsWeb.CommentComponents do
  @moduledoc """
  Comment-related components for the ElixirDrops application.
  """

  use ElixirDropsWeb, :html

  attr :streams, :map, required: true
  attr :comment_count, :integer, required: true
  attr :current_user, :map
  attr :drop_id, :string, required: true
  attr :has_more_comments, :boolean, default: false
  attr :replying_to, :string, default: nil
  attr :editing_comment, :string, default: nil
  attr :comment_changeset, :any, default: nil
  attr :current_url, :string, default: "/"

  @spec comment_section(map()) :: Phoenix.LiveView.Rendered.t()
  def comment_section(assigns) do
    ~H"""
    <div class="comments-section mt-8 border-t pt-8">
      <h3 class="text-lg font-semibold mb-6 text-gray-900">
        Comments (<%= @comment_count %>)
      </h3>

      <%= if @current_user do %>
        <.comment_form drop_id={@drop_id} changeset={@comment_changeset} />
      <% else %>
        <div class="mb-6 p-4 bg-gray-50 rounded-lg border">
          <p class="text-gray-600 text-center">
            <.link
              href={~p"/auth/github" <> "?return_to=#{assigns[:current_url] || "/"}"}
              class="text-blue-600 hover:text-blue-800 font-medium"
            >
              Sign in with GitHub
            </.link>
            to join the discussion
          </p>
        </div>
      <% end %>

      <div id="comments" phx-update="stream" class="space-y-6">
        <%= for {dom_id, comment} <- @streams.comments do %>
          <div id={dom_id}>
            <.comment
              comment={comment}
              current_user={@current_user}
              replying_to={@replying_to}
              editing_comment={@editing_comment}
              drop_id={@drop_id}
            />
          </div>
        <% end %>
      </div>

      <%= if @has_more_comments do %>
        <div class="mt-6 text-center">
          <button
            phx-click="load_more_comments"
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            Load more comments
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  attr :comment, :map, required: true
  attr :current_user, :map
  attr :level, :integer, default: 0
  attr :replying_to, :string, default: nil
  attr :editing_comment, :string, default: nil
  attr :drop_id, :string, required: true

  @spec comment(map()) :: Phoenix.LiveView.Rendered.t()
  def comment(assigns) do
    ~H"""
    <div
      class={"comment #{if @level > 0, do: "ml-8 border-l-2 border-gray-200 pl-4"}"}
      id={"comment-#{@comment.id}"}
    >
      <%= if @comment.deleted_at do %>
        <div class="py-3">
          <p class="text-gray-500 italic text-sm">[deleted]</p>
        </div>
      <% else %>
        <div class="flex items-start gap-3">
          <img
            src={@comment.user.avatar || "/images/default-avatar.svg"}
            alt={@comment.user.name}
            class="w-8 h-8 rounded-full border border-gray-200 flex-shrink-0"
          />
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 text-sm text-gray-600 mb-1">
              <span class="font-medium text-gray-900"><%= @comment.user.name %></span>
              <span class="text-gray-400">•</span>
              <time class="text-gray-500">
                <%= format_relative_time(@comment.inserted_at) %>
              </time>
              <%= if @comment.edited_at do %>
                <span class="text-gray-400">•</span>
                <span class="text-gray-500 italic">edited</span>
              <% end %>
            </div>

            <%= if @editing_comment == @comment.id do %>
              <.edit_comment_form comment={@comment} />
            <% else %>
              <div class="comment-body prose prose-sm max-w-none mb-3">
                <%= raw(@comment.body_html) %>
              </div>
            <% end %>

            <%= if @editing_comment != @comment.id do %>
              <div class="flex items-center gap-4 text-sm">
                <%= if @current_user do %>
                  <button
                    phx-click="reply"
                    phx-value-comment-id={@comment.id}
                    class="text-gray-500 hover:text-gray-700 font-medium"
                  >
                    Reply
                  </button>
                <% end %>

                <%= if @current_user && @current_user.id == @comment.user_id do %>
                  <button
                    phx-click="edit_comment_toggle"
                    phx-value-comment-id={@comment.id}
                    class="text-gray-500 hover:text-gray-700 font-medium"
                  >
                    Edit
                  </button>
                  <button
                    phx-click="delete_comment"
                    phx-value-comment-id={@comment.id}
                    class="text-red-500 hover:text-red-700 font-medium"
                    onclick="return confirm('Are you sure you want to delete this comment?')"
                  >
                    Delete
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%= if @replying_to == @comment.id do %>
          <div class="mt-4">
            <.reply_form comment_id={@comment.id} />
          </div>
        <% end %>

        <%= if is_list(@comment.replies) && length(@comment.replies) > 0 do %>
          <div class="mt-4 space-y-4">
            <%= for reply <- @comment.replies do %>
              <.comment
                comment={reply}
                current_user={@current_user}
                level={1}
                replying_to={@replying_to}
                editing_comment={@editing_comment}
                drop_id={@drop_id}
              />
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :drop_id, :string, required: true
  attr :changeset, :any, required: true

  @spec comment_form(map()) :: Phoenix.LiveView.Rendered.t()
  def comment_form(assigns) do
    ~H"""
    <div class="comment-form mb-6">
      <.form
        for={@changeset}
        phx-submit="new_comment"
        phx-change="validate_comment"
        class="space-y-4"
        id="comment-form"
      >
        <div>
          <label for="comment_body" class="sr-only">Add a comment</label>
          <textarea
            id="comment_body"
            name="comment[body]"
            value={Ecto.Changeset.get_field(@changeset, :body) || ""}
            rows="3"
            placeholder="Write a comment..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
            maxlength="1000"
            required
          />
          <%= if @changeset.action do %>
            <div class="mt-2">
              <%= for {_field, {msg, _opts}} <- @changeset.errors do %>
                <p class="text-sm text-red-600"><%= msg %></p>
              <% end %>
            </div>
          <% end %>
          <div class="mt-2 flex justify-between items-center">
            <div class="text-xs text-gray-500 space-y-1">
              <p>Supports basic Markdown: **bold**, *italic*, and [links](url).</p>
              <p>Max 1000 characters.</p>
            </div>
            <button
              type="submit"
              class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              Post Comment
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  attr :comment_id, :string, required: true

  @spec reply_form(map()) :: Phoenix.LiveView.Rendered.t()
  def reply_form(assigns) do
    ~H"""
    <div class="reply-form">
      <.form
        for={%{}}
        phx-submit="reply_to_comment"
        phx-value-comment-id={@comment_id}
        class="space-y-3"
      >
        <div>
          <label for={"reply_body_#{@comment_id}"} class="sr-only">Write a reply</label>
          <textarea
            id={"reply_body_#{@comment_id}"}
            name="comment[body]"
            rows="2"
            placeholder="Write a reply..."
            class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
            maxlength="1000"
            required
          ></textarea>
        </div>
        <div class="flex justify-start gap-2">
          <button
            type="submit"
            class="px-3 py-1.5 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            Reply
          </button>
          <button
            type="button"
            phx-click="cancel_reply"
            class="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            Cancel
          </button>
        </div>
      </.form>
    </div>
    """
  end

  attr :comment, :map, required: true

  @spec edit_comment_form(map()) :: Phoenix.LiveView.Rendered.t()
  def edit_comment_form(assigns) do
    ~H"""
    <div class="edit-comment-form">
      <.form
        for={%{}}
        phx-submit="update_comment"
        phx-value-comment-id={@comment.id}
        class="space-y-3"
      >
        <div>
          <label for={"edit_body_#{@comment.id}"} class="sr-only">Edit comment</label>
          <textarea
            id={"edit_body_#{@comment.id}"}
            name="comment[body]"
            rows="3"
            value={@comment.body}
            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
            maxlength="1000"
            required
          ><%= @comment.body %></textarea>
        </div>
        <div class="flex justify-start gap-2">
          <button
            type="submit"
            class="px-3 py-1.5 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            Save
          </button>
          <button
            type="button"
            phx-click="cancel_edit"
            class="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            Cancel
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    datetime_utc = DateTime.from_naive!(datetime, "Etc/UTC")
    diff = DateTime.diff(now, datetime_utc, :second)

    cond do
      diff < 60 ->
        "just now"

      diff < 3600 ->
        minutes = div(diff, 60)
        "#{minutes}m ago"

      diff < 86_400 ->
        hours = div(diff, 3600)
        "#{hours}h ago"

      diff < 2_592_000 ->
        days = div(diff, 86_400)
        "#{days}d ago"

      true ->
        months = div(diff, 2_592_000)
        "#{months}mo ago"
    end
  end
end
