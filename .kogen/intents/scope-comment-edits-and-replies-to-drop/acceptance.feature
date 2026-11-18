Feature: Comment edits and replies are scoped to the author and the Drop
  This feature runs synthetic isolated records through the comments context and the real Drop LiveView and checks stored rows and the displayed thread.

  Scenario: The author edits their own comment
    Then scope-comment-edits-and-replies-to-drop: the isolated test "author edits own comment on its Drop" passes

  Scenario: Other comments cannot be edited
    Then scope-comment-edits-and-replies-to-drop: the isolated test "other user, other Drop, unknown and malformed ids are not found and change nothing" passes

  Scenario: A reply must stay on the Drop of its parent
    Then scope-comment-edits-and-replies-to-drop: the isolated test "reply under another Drop's parent is refused and same-Drop reply works" passes

  Scenario: A forged edit event changes nothing
    Then scope-comment-edits-and-replies-to-drop: the isolated test "forged edit event changes nothing and the author edit still works" passes
