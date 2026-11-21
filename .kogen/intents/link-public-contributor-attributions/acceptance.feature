Feature: Public contributor attributions link to profiles
  This feature makes contributor avatars and names on Drop cards, Drop detail and comments genuine links to the contributor's existing public profile.

  Scenario: Drop card and Drop detail author links name the displayed author for guest and signed-in readers
    Then link-public-contributor-attributions: each fixture card and Drop detail links its own displayed author and never the visitor or another author, for a guest and for a signed-in third user, in file "viewers_test.exs" test "card and detail author links target the displayed author for guest and third user"

  Scenario: Comment and reply authors are linked to their own profiles
    Then link-public-contributor-attributions: the avatar and the name of the comment author and of the reply author both link to their own different profiles, not only the top-level comment, not only the name and not the Drop author, in file "discussion_test.exs" test "comment and reply avatar and name link to their own authors"

  Scenario: Author links work natively in a real browser at three widths
    Then link-public-contributor-attributions: keyboard, Control-click and middle-click on an author link reach the author profile natively with no nested anchors, no Drop navigation and a visible focus indicator and pointer cursor at 320, 390 and 1280 pixels, in file "browser_test.exs" test "author links behave as native independent anchors at 320, 390 and 1280 px"

  Scenario: An unresolvable author stays unlinked and no private data is rendered
    Then link-public-contributor-attributions: the resolvable author is linked, the unresolvable author has no profile link, empty link or placeholder link, and no email or account secret is rendered, in file "unresolvable_test.exs" test "unresolvable author is unlinked, resolvable author linked, no private data"
