defmodule ElixirDropsWeb.DropComponentsTest do
  # Fast rendered-markup checks for the interaction and accessibility repair.
  # Real clicks, keyboard and focus are covered by the browser tests in
  # test/elixir_drops_web/features/accessible_controls_test.exs.
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    user = user_fixture(%{github_username: "markup_user"})
    drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user, %{title: "Markup drop"})
    %{conn: sign_in_user(conn, user), drop: drop, user: user}
  end

  test "every rendered image has an alt attribute and avatars are decorative", %{
    conn: conn,
    drop: drop
  } do
    {:ok, _live, html} = live(conn, ~p"/")

    refute html =~ ~r/<img(?![^>]*\balt=)/
    refute html =~ "notification icon"
    assert html =~ ~s(src="#{drop.user.avatar}" alt="")
  end

  test "the card title is a native link to the Drop", %{conn: conn, drop: drop} do
    {:ok, live, _html} = live(conn, ~p"/")

    assert has_element?(live, "#drop-#{drop.id} h3.drop-title a[href='/d/#{drop.short_id}']")
    refute has_element?(live, "#drop-#{drop.id}[role='link']")
    refute has_element?(live, "#drop-#{drop.id} a.hidden")
  end

  test "copy actions are named buttons and the clipboard message is a polite live region", %{
    conn: conn,
    drop: drop
  } do
    {:ok, live, _html} = live(conn, ~p"/")

    assert has_element?(live, "#card-copy-link-menu-#{drop.id}[type=button]")
    assert has_element?(live, "button#copy-markdown-#{drop.short_id}[type=button]")
    refute has_element?(live, "div[phx-hook='CopyToClipboard']")
    assert has_element?(live, "#copy-confirm-message[role=status][aria-live=polite]")
  end

  test "header triggers are named buttons that report their expanded state", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")

    for id <-
          ~w(account-menu-trigger notifications-trigger-mobile notifications-trigger search-trigger) do
      assert has_element?(live, "button##{id}[aria-label][aria-expanded=false][aria-controls]"),
             "#{id} must be a named button with aria-expanded"
    end
  end

  test "the card menu button exposes aria-expanded and aria-controls", %{conn: conn, drop: drop} do
    {:ok, live, _html} = live(conn, ~p"/")

    assert has_element?(
             live,
             "#drop-card-menu-btn-#{drop.id}[aria-label][aria-expanded=false][aria-controls='drop-card-menu-#{drop.id}']"
           )
  end

  test "popups are modal dialogs with accessible names", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")

    assert has_element?(
             live,
             "#signin-popup-message[role=dialog][aria-modal=true][aria-labelledby][phx-key=escape]"
           )

    assert has_element?(
             live,
             "#edit-form-cancel-confirm[role=alertdialog][aria-modal=true][aria-labelledby][phx-key=escape]"
           )
  end

  test "the drop page copy action and menu button are accessible", %{conn: conn, drop: drop} do
    {:ok, live, _html} = live(conn, ~p"/d/#{drop.short_id}")

    assert has_element?(live, "button#single-drop-copy-link-#{drop.id}[type=button][aria-label]")

    assert has_element?(
             live,
             "#action-row-menu-btn-#{drop.id}[aria-label][aria-expanded=false][aria-controls='drop-menu-#{drop.id}']"
           )
  end
end
