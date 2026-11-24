defmodule RevealProfileReplyOnMobile.DiscussionTest do
  use ElixirDropsWeb.FeatureCase, async: false

  import Ecto.Query
  import ElixirDrops.CommentsFixtures

  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo
  alias PhoenixTest.Playwright.Connection
  alias PhoenixTest.Playwright.Frame

  @moduletag :feature
  @moduletag timeout: 90_000
  @connected "window.liveSocket?.isConnected() === true && !!document.querySelector('.phx-connected')"
  @viewports [{390, 844}, {1280, 800}]

  @tag :discussion_journey
  test "reveal the selected older public discussion entries", %{conn: conn} do
    run_journey(conn, [:connected, :full_document])
  end

  @tag :discussion_observer_good
  test "qualify the observer on connected navigation", %{conn: conn} do
    run_journey(conn, [:connected])
  end

  @tag :discussion_observer_bad
  test "qualify the observer on the baseline full-document navigation", %{conn: conn} do
    run_journey(conn, [:full_document])
  end

  defp run_journey(conn, modes) do
    {author, drop, reply, old} = older_conversation()
    profile = "/u/#{author.id}"
    session = visit(conn, "/")

    unwrap(session, fn %{frame_id: frame, page_id: page} ->
      rows =
        for {width, height} <- @viewports, reduce: [] do
          rows ->
            resize_window(session, width, height)
            visit(session, "/")
            open_comments(frame, profile, reply)

            cases =
              Enum.flat_map(modes, fn
                :connected -> [{reply, "connected"}, {old, "connected"}]
                :full_document -> [{reply, "full-document"}]
              end)

            rows ++
              Enum.map(cases, fn {comment, mode} ->
                follow(session, frame, page, profile, drop, comment, mode, {width, height})
              end)
        end

      IO.puts("DISCUSSION_EVIDENCE " <> Jason.encode!(rows))
      hidden = Enum.reject(rows, &(&1["visible"] and &1["inViewport"]))

      assert hidden == [],
             "selected discussion body not visible in viewport: #{Jason.encode!(hidden)}"
    end)
  end

  # Same older-thread shape and timestamps as the landed discussion browser fixture.
  # Its second Drop supplies the homepage attribution for the selected contributor.
  defp older_conversation do
    author = user_fixture(%{name: "Disc Author"})
    rival = user_fixture(%{name: "Disc Rival"})
    drop = drop_fixture(%Drop{}, rival, %{title: "Deep Drop"})
    drop_fixture(%Drop{}, author, %{title: "Long Drop"})

    for index <- 1..25 do
      token = index |> Integer.to_string() |> String.pad_leading(4, "0")
      comment = comment_fixture(drop, rival, nil, %{body: "OTH-#{token} newer conversation"})
      date_comment(comment, NaiveDateTime.add(~N[2025-06-01 12:00:00], index * 60))
    end

    parent = comment_fixture(drop, rival, nil, %{body: "PAR-0001 oldest conversation"})
    date_comment(parent, ~N[2023-01-01 12:00:00])
    reply = comment_fixture(drop, author, parent, %{body: "RPL-0001 old reply"})
    date_comment(reply, ~N[2024-05-01 12:00:00])
    old = comment_fixture(drop, author, nil, %{body: "CMT-0002 old top-level comment"})
    date_comment(old, ~N[2023-06-01 12:00:00])
    {author, drop, reply, old}
  end

  defp date_comment(comment, date) do
    Repo.update_all(from(c in Comment, where: c.id == ^comment.id), set: [inserted_at: date])
  end

  defp open_comments(frame, profile, reply) do
    click_anchor(frame, ".drop-card a[href='#{profile}']:not([aria-hidden='true'])")

    wait_for(frame, "guest profile on Drops", """
    return #{@connected} && ['#{profile}', '#{profile}/drops'].includes(location.pathname)
      && document.querySelector('#profile-drops-tab')?.getAttribute('aria-current') === 'page';
    """)

    # Focus the existing Drops link as a starting point; Tab must reach Comments.
    Frame.evaluate(frame, "document.querySelector('#profile-drops-tab').focus()")
    {:ok, _} = Frame.press(frame, "#profile-drops-tab", "Tab")
    assert Frame.evaluate(frame, "document.activeElement.id") == "profile-comments-tab"
    {:ok, _} = Frame.press(frame, "#profile-comments-tab:focus", "Enter")
    on_comments(frame, profile, reply)
  end

  defp on_comments(frame, profile, comment) do
    wait_for(frame, "connected Comments with selected entry (including after Back)", """
    return #{@connected} && location.pathname === '#{profile}/comments'
      && document.querySelector('#profile-comments-tab')?.getAttribute('aria-current') === 'page'
      && document.getElementById('profile-comment-body-#{comment.id}')?.checkVisibility();
    """)
  end

  defp follow(session, frame, page, profile, drop, comment, mode, {width, height}) do
    link =
      "[data-feed-entry]:has(#profile-comment-body-#{comment.id}) a:text-is('View in discussion')"

    href =
      Frame.evaluate(frame, """
      (() => {
        const body = document.getElementById('profile-comment-body-#{comment.id}');
        const links = [...body.closest('[data-feed-entry]').querySelectorAll('a')]
          .filter(a => a.textContent.trim() === 'View in discussion');
        window.__profileDiscussionJourney = true;
        return links.length === 1 && links[0].checkVisibility() ? links[0].href : null;
      })()
      """)

    assert is_binary(href), "no unique visible View in discussion link for #{comment.body}"
    uri = URI.parse(href)
    assert uri.path == "/d/#{drop.short_id}"
    assert URI.decode_query(uri.query) == discussion_query(comment)

    assert URI.to_string(%{uri | path: nil, query: nil, fragment: nil}) ==
             ElixirDropsWeb.Endpoint.url()

    if mode == "full-document", do: visit(session, href), else: click_anchor(frame, link)

    wait_for(frame, "guest connected to exact Drop URL (#{mode})", """
    return #{@connected} && location.href === #{Jason.encode!(href)}
      && [...document.querySelectorAll('a')].some(a => a.textContent.trim() === 'Sign in with GitHub'
        && a.parentElement.textContent.includes('to join the discussion'));
    """)

    assert Frame.evaluate(frame, "window.__profileDiscussionJourney === true") ==
             (mode == "connected"),
           "#{mode} did not use its expected document lifecycle"

    observed = observe_body(frame, comment)

    assert %{
             "text" => text,
             "matches" => 1,
             "nested" => true,
             "width" => ^width,
             "height" => ^height
           } = observed

    assert text == comment.body

    response =
      Connection.post(
        guid: page,
        method: :go_back,
        params: %{wait_until: "domcontentloaded", timeout: 5_000}
      )

    refute Map.has_key?(response, :error), "Back failed: #{inspect(response)}"
    on_comments(frame, profile, comment)
    Map.merge(observed, %{"mode" => mode, "href" => href, "back" => profile <> "/comments"})
  end

  defp discussion_query(%{id: id, parent_id: nil}), do: %{"comment_id" => id}

  defp discussion_query(%{id: id, parent_id: parent}),
    do: %{"comment_id" => id, "comment_parent_id" => parent}

  defp observe_body(frame, comment) do
    Frame.evaluate(
      frame,
      """
      (async () => {
        function observe() {
          const matches = document.querySelectorAll('#comment-body-#{comment.id}');
          const body = matches[0];
          const paragraph = body?.querySelector('p');
          const rect = paragraph?.getBoundingClientRect();
          const parent = document.getElementById('comment-replies-#{comment.parent_id}');
          const style = parent && getComputedStyle(parent);
          const visible = !!paragraph?.checkVisibility({opacityProperty: true, visibilityProperty: true});
          return {
            width: innerWidth, height: innerHeight, matches: matches.length,
            text: paragraph?.textContent.trim() ?? null,
            nested: parent ? parent.contains(body) : #{is_nil(comment.parent_id)},
            parentDisplay: style?.display ?? null,
            visible, inViewport: !!rect && rect.width > 0 && rect.height > 0
              && rect.top >= 0 && rect.bottom <= innerHeight && rect.left >= 0 && rect.right <= innerWidth
          };
        }
        const deadline = performance.now() + 3500;
        let result = observe();
        while (!(result.visible && result.inViewport) && performance.now() < deadline) {
          await new Promise(resolve => setTimeout(resolve, 50));
          result = observe();
        }
        return result;
      })()
      """,
      timeout: 5_000
    )
  end

  defp click_anchor(frame, selector) do
    {:ok, _} = Frame.click(frame, selector, %{timeout: 3_000})
  end

  defp wait_for(frame, label, condition) do
    result =
      Frame.evaluate(
        frame,
        """
        (async () => {
          const ready = () => { #{condition} };
          const deadline = performance.now() + 4000;
          while (!ready() && performance.now() < deadline) await new Promise(resolve => setTimeout(resolve, 50));
          return ready() ? 'ok' : location.href;
        })()
        """,
        timeout: 5_000
      )

    assert result == "ok", "#{label}: #{inspect(result)}"
  end
end
