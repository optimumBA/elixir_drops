Feature: Comment deletion is authorized by the current user and the viewed Drop
  This feature runs synthetic isolated records through the real Drop LiveView and checks stored rows, counts and the displayed thread.

  Scenario: A guest cannot delete a comment
    Then authorize-comment-deletion-by-user-and-drop: the isolated regression "guest deletion is rejected without mutation" passes

  Scenario: An authenticated user cannot delete another author's comment
    Then authorize-comment-deletion-by-user-and-drop: the isolated regression "other author comment is rejected without mutation" passes

  Scenario: An authenticated user cannot delete a comment of a different Drop
    Then authorize-comment-deletion-by-user-and-drop: the isolated regression "other Drop comment is rejected without mutation" passes

  Scenario: The author deletes a top-level comment
    Then authorize-comment-deletion-by-user-and-drop: the isolated regression "author deletes a top-level comment" passes

  Scenario: The author deletes a reply
    Then authorize-comment-deletion-by-user-and-drop: the isolated regression "author deletes a reply" passes
