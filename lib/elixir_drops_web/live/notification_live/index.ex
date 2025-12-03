defmodule ElixirDropsWeb.NotificationLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Notifications

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    notifications = Notifications.list_user_notifications(user_id)

    {:ok,
     socket
     |> assign(:notifications_empty?, Enum.empty?(notifications))
     |> stream(:notifications, notifications, reset: true), layout: false}
  end

  defp notification_card(assigns) do
    ~H"""
    <div class="w-[94%] mx-auto flex gap-4">
      <section class="shrink-0 pt-1 md:pt-0">
        <img
          src={@actor.avatar || "/images/default-avatar.svg"}
          alt={@actor.name}
          class="w-11 h-11 rounded-full"
        />
      </section>

      <section class="flex flex-col gap-3 roboto-regular">
        <p class="text-sm leading-5 text-[#252525]">
          {@actor.name} {add_body(@notification_type)} -
          <a
            class="text-[#5947F1] hover:underline hover:cursor-pointer"
            href={
              navigate_to_comment_page(
                @comment,
                @comment.parent_id
              )
            }
          >
            {@comment.drop.title}
          </a>
        </p>
        <p class="text-xs text-[#8E8E8E] leading-4">
          {Timex.format!(@time_created, "{relative}", :relative)}
        </p>
      </section>
    </div>
    """
  end

  defp navigate_to_comment_page(comment, nil),
    do: ~p"/d/#{comment.drop.short_id}/#comment-#{comment.id}"

  defp navigate_to_comment_page(comment, parent_id),
    do: ~p"/d/#{comment.drop.short_id}/?comment_parent_id=#{parent_id}&comment_id=#{comment.id}"

  defp add_body(:comment_on_post), do: "commented on your post"
  defp add_body(:reply_to_comment), do: "replied to your comment on"
end
