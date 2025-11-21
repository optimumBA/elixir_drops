defmodule ElixirDropsWeb.Comment.FormComponent do
  @moduledoc false
  use ElixirDropsWeb, :live_component

  alias ElixirDrops.Comments
  alias ElixirDrops.Comments.Comment

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div>
      <.form
        class={@class}
        for={@form}
        id={@id}
        phx-change="validate_comment"
        phx-hook="CommentForm"
        phx-submit={submit_form(@comment, @parent, @comment_type)}
        phx-target={@myself}
      >
        <div class="group">
          <.custom_input
            id={@field_id}
            class={[
              "border-[1px] border-gray-200 focus-within:border-[#2F19EE] px-2 py-3 ",
              "rounded-lg transition-colors duration-100"
            ]}
            input_field_class={[
              "border-0 py-0 block w-full",
              "text-[#252525] focus:ring-0 sm:text-sm sm:leading-6",
              "placeholder:italic placeholder:text-[#9D9D9D]"
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
              <div
                :if={!@comment and @comment_type == :comment}
                class={[
                  "flex justify-end gap-x-4 mt-12 pointer-events-none group-focus-within:opacity-100 group-focus-within:pointer-events-auto group-hover:pointer-events-auto",
                  "opacity-0"
                ]}
              >
                <button
                  id={"#{@id}-cancel-btn"}
                  phx-click="cancel_new_comment"
                  phx-target={@myself}
                  type="button"
                  class="hover:opacity-80"
                >
                  Cancel
                </button>
                <button
                  id={"submit-button-#{@id}"}
                  class="bg-blue-500 text-white text-sm px-4 py-2 rounded-md hover:opacity-70 disabled:bg-[#BFB8FA] disabled:cursor-not-allowed"
                  type="submit"
                  onclick="event.stopPropagation()"
                  disabled
                >
                  <span>Comment</span>
                </button>
              </div>
              <div
                :if={@comment || @comment_type == :response}
                class={[
                  "justify-end gap-x-4 mt-16 flex"
                ]}
              >
                <button
                  phx-click={
                    if @comment,
                      do: JS.toggle_class("hidden", to: "##{@id}"),
                      else: JS.hide(to: "##{@id}")
                  }
                  type="button"
                  class="hover:opacity-80"
                >
                  Cancel
                </button>
                <button
                  id={"submit-button-#{@id}"}
                  class="bg-blue-500 text-white text-sm px-4 py-2 rounded-md hover:opacity-70 disabled:bg-[#BFB8FA] disabled:cursor-not-allowed"
                  type="submit"
                  disabled
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
          <p>
            Supports basic Markdown<span class="hidden sm:inline-block">: **bold**, *italic*, and [links](url)</span>.
          </p>
          <p>
            <span class="hidden sm:inline-block">Max 1000 characters</span>
            (<span id={"#{@id}-char-count"}>0</span>/1000)
          </p>
        </div>
      </.form>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    form =
      %Comment{}
      |> Comments.change_comment()
      |> to_form()

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(assigns)}
  end

  @impl Phoenix.LiveComponent
  def handle_event(
        "validate_comment",
        %{
          "comment" => %{"body" => body} = params
        },
        socket
      ) do
    form_id = socket.assigns.id
    character_count = String.length(body)

    if socket.assigns.comment do
      {:noreply,
       push_event(socket, "reply_char_count", %{count: character_count, form_id: form_id})}
    else
      changeset = Comments.change_comment(%Comment{}, params)

      {:noreply,
       socket
       |> assign(:form, to_form(changeset))
       |> push_event("reply_char_count", %{count: character_count, form_id: form_id})}
    end
  end

  def handle_event(
        "new_comment",
        %{"comment" => comment_params},
        socket
      ) do
    comment_type = socket.assigns.comment_type
    parent = socket.assigns.parent
    parent_id = if parent, do: parent.id, else: nil
    notify_parent({:new_comment, parent_id, comment_type, comment_params})
    {:noreply, socket}
  end

  def handle_event(
        "update_comment",
        %{"comment" => comment_params, "comment_id" => comment_id},
        socket
      ) do
    comment_params = Map.merge(comment_params, %{"edited_at" => DateTime.utc_now()})
    comment = Comments.get_comment!(comment_id)
    notify_parent({:update_comment, comment, comment_params})
    {:noreply, socket}
  end

  def handle_event("cancel_new_comment", _params, socket) do
    changeset =
      Comments.change_comment(
        %Comment{},
        %{"body" => ""}
      )

    {
      :noreply,
      socket
      |> assign(:character_count, 0)
      |> assign(:form, to_form(changeset))
      |> push_event("cancel_comment", %{})
    }
  end

  def handle_event(
        "change_edit_comment_form",
        %{"comment_id" => comment_id},
        socket
      ) do
    comment = Comments.get_comment!(comment_id)
    character_count = String.length(comment.body)
    form_id = "edit-comment-form-#{comment_id}"

    form =
      comment
      |> Comments.change_comment()
      |> to_form()

    {:noreply,
     socket
     |> assign(:form, form)
     |> push_event("edit_comment", %{comment_id: comment_id})
     |> push_event("reply_char_count", %{count: character_count, form_id: form_id})}
  end

  defp submit_form(%Comment{} = comment, _parent, _comment_type),
    do: JS.push("update_comment", value: %{comment_id: comment.id})

  defp submit_form(nil, _parent, :comment), do: JS.push("new_comment")

  defp submit_form(nil, parent, :response) do
    "new_comment"
    |> JS.push()
    |> JS.toggle(to: "#reply-form-#{parent.id}")
  end

  defp notify_parent(msg), do: send(self(), msg)
end
