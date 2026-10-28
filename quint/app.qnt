/// Whole-app identity/content/comment/notification contract. See ../spec/README.md.
module app {
  pure val USERS = Set(1, 2, 3)
  pure val DEVICES = Set(1, 2, 3)
  pure val DROPS = Set(1, 2, 3, 4)
  pure val COMMENTS = Set(1, 2, 3, 4, 5, 6)
  pure val SESSION_TTL = 60 * 24 * 60 * 60
  type Session = { user: int, epoch: int, issued: int, present: bool, cookie: bool }
  type Drop = { exists: bool, owner: int, revision: int, titleLength: int, bodyLength: int, code: int }
  type Comment = { exists: bool, owner: int, drop: int, parent: int, bodyLength: int, edited: bool }
  type Notice = { comment: int, actor: int, recipient: int, kind: str, read: bool }
  type State = {
    now: int, users: Set[int], epochs: int -> int, sessions: int -> Session,
    drops: int -> Drop, comments: int -> Comment, notices: Set[Notice], pending: Set[Notice]
  }
  pure val emptyDrop: Drop = { exists: false, owner: 0, revision: 0, titleLength: 0, bodyLength: 0, code: 0 }
  pure val emptyComment: Comment = { exists: false, owner: 0, drop: 0, parent: 0, bodyLength: 0, edited: false }
  pure val initial: State = {
    now: 0, users: Set(), epochs: USERS.mapBy(_ => 0),
    sessions: DEVICES.mapBy(_ => {user: 0, epoch: 0, issued: 0, present: false, cookie: false}),
    drops: DROPS.mapBy(_ => emptyDrop), comments: COMMENTS.mapBy(_ => emptyComment),
    notices: Set(), pending: Set()
  }
  var contentState: State
  var contentBefore: State
  var contentCommand: { name: str, device: int, target: int, accepted: bool }
  action move(stateAfter: State, name: str, device: int, target: int, accepted: bool): bool = all {
    contentBefore' = contentState, contentState' = stateAfter, contentCommand' = {name: name, device: device, target: target, accepted: accepted}
  }
  action init = all {
    contentState' = initial, contentBefore' = initial,
    contentCommand' = {name: "init", device: 0, target: 0, accepted: true}
  }
  pure def principalAt(state: State, device: int): int = {
    val token = state.sessions.get(device)
    if (token.present and token.user.in(state.users)) {
      if (token.epoch == state.epochs.get(token.user) and state.now - token.issued < SESSION_TTL) token.user else 0
    } else 0
  }
  def principal(device: int): int = principalAt(contentState, device)
  // User identity is the abstract GitHub ID; repeated login reuses the user.
  action login(device: int, user: int): bool = {
    val epoch = contentState.epochs.get(user) + 1
    move({...contentState, users: contentState.users.union(Set(user)), epochs: contentState.epochs.set(user, epoch),
      sessions: contentState.sessions.set(device, {user: user, epoch: epoch, issued: contentState.now, present: true, cookie: true})},
      "login", device, user, true)
  }
  action oauthFailure(device: int): bool = move(contentState, "oauthFailure", device, 0, false)
  action logout(device: int): bool = move({...contentState, sessions: contentState.sessions.setBy(device, t => {...t, present: false, cookie: false})},
    "logout", device, 0, true)
  // Cookie restoration is allowed only while the backing token is valid.
  action loseBrowserSession(device: int): bool = move({...contentState, sessions: contentState.sessions.setBy(device, t => {...t, present: false})},
    "loseBrowserSession", device, 0, true)
  action restoreCookie(device: int): bool = {
    val t = contentState.sessions.get(device)
    val ok = if (t.cookie and t.user.in(contentState.users))
      t.epoch == contentState.epochs.get(t.user) and contentState.now - t.issued < SESSION_TTL else false
    move(if (ok) {...contentState, sessions: contentState.sessions.setBy(device, t => {...t, present: true})} else contentState,
      "restoreCookie", device, 0, ok)
  }
  action tick(seconds: int): bool = move({...contentState, now: contentState.now + seconds}, "tick", 0, seconds, true)
  pure def validDrop(titleLength: int, bodyLength: int): bool =
    titleLength > 0 and titleLength <= 255 and bodyLength > 0
  action publish(device: int, d: int, titleLength: int, bodyLength: int, code: int): bool = {
    val user = principal(device)
    val ok = user != 0 and not(contentState.drops.get(d).exists) and validDrop(titleLength, bodyLength)
    move(if (ok) {...contentState, drops: contentState.drops.set(d, {exists: true, owner: user, revision: 1,
      titleLength: titleLength, bodyLength: bodyLength, code: code})} else contentState, "publish", device, d, ok)
  }
  action editDrop(device: int, d: int, titleLength: int, bodyLength: int, code: int): bool = {
    val old = contentState.drops.get(d)
    val ok = principal(device) != 0 and old.exists and old.owner == principal(device) and validDrop(titleLength, bodyLength)
    move(if (ok) {...contentState, drops: contentState.drops.set(d, {...old, revision: old.revision + 1,
      titleLength: titleLength, bodyLength: bodyLength, code: code})} else contentState, "editDrop", device, d, ok)
  }
  def validParent(d: int, parent: int): bool = if (parent == 0) true else {
    val p = contentState.comments.get(parent)
    p.exists and p.drop == d and p.parent == 0
  }
  pure def notice(c: int, actor: int, recipient: int, kind: str): Notice =
    {comment: c, actor: actor, recipient: recipient, kind: kind, read: false}
  def recipients(c: int, actor: int, d: int, parent: int): Set[Notice] = {
    val author = contentState.drops.get(d).owner
    val topAuthor = if (parent == 0) actor else contentState.comments.get(parent).owner
    val reply = if (parent != 0 and topAuthor != actor) Set(notice(c, actor, topAuthor, "reply_to_comment")) else Set()
    val post = if (author != topAuthor and author != actor) Set(notice(c, actor, author, "comment_on_post")) else Set()
    reply.union(post)
  }
  action addComment(device: int, c: int, d: int, parent: int, bodyLength: int): bool = {
    val user = principal(device)
    val ok = user != 0 and not(contentState.comments.get(c).exists) and contentState.drops.get(d).exists and validParent(d, parent)
      and bodyLength > 0 and bodyLength <= 1000
    move(if (ok) {...contentState, comments: contentState.comments.set(c, {exists: true, owner: user, drop: d, parent: parent,
      bodyLength: bodyLength, edited: false}), pending: contentState.pending.union(recipients(c, user, d, parent))} else contentState,
      "addComment", device, c, ok)
  }
  action editComment(device: int, c: int, bodyLength: int): bool = {
    val old = contentState.comments.get(c)
    val ok = principal(device) != 0 and old.exists and old.owner == principal(device) and bodyLength > 0 and bodyLength <= 1000
    move(if (ok) {...contentState, comments: contentState.comments.set(c, {...old, bodyLength: bodyLength, edited: true})} else contentState,
      "editComment", device, c, ok)
  }
  // Physical deletion cascades to direct replies and their notifications.
  action deleteComment(device: int, c: int): bool = {
    val old = contentState.comments.get(c)
    val ok = principal(device) != 0 and old.exists and old.owner == principal(device)
    val removed = COMMENTS.filter(id => id == c or contentState.comments.get(id).parent == c)
    move(if (ok) {...contentState, comments: COMMENTS.mapBy(id => if (removed.contains(id)) emptyComment else contentState.comments.get(id)),
      notices: contentState.notices.filter(n => not(removed.contains(n.comment))),
      pending: contentState.pending.filter(n => not(removed.contains(n.comment)))} else contentState, "deleteComment", device, c, ok)
  }
  // Notification insert can fail independently after the comment committed.
  action deliverNotice(n: Notice, success: bool): bool = all {
    contentState.pending.contains(n),
    move({...contentState, pending: contentState.pending.exclude(Set(n)), notices: if (success) contentState.notices.union(Set(n)) else contentState.notices},
      "deliverNotice", 0, n.comment, true)
  }
  action markRead(device: int): bool = {
    val user = principal(device)
    val ok = user != 0
    move(if (ok) {...contentState, notices: contentState.notices.map(n => if (n.recipient == user) {...n, read: true} else n)} else contentState,
      "markRead", device, user, ok)
  }
  def unread(user: int): Set[Notice] = contentState.notices.filter(n => n.recipient == user and not(n.read))
  val referentialIntegrity = all {
    DROPS.forall(d => contentState.drops.get(d).exists.implies(contentState.drops.get(d).owner.in(contentState.users))),
    COMMENTS.forall(c => {
      val row = contentState.comments.get(c)
      row.exists.implies(row.owner.in(contentState.users) and contentState.drops.get(row.drop).exists and validParent(row.drop, row.parent))
    }),
    contentState.notices.union(contentState.pending).forall(n => contentState.comments.get(n.comment).exists and n.actor.in(contentState.users)
      and n.recipient.in(contentState.users) and n.actor != n.recipient)
  }
  val validContent = all {
    DROPS.forall(d => {val row = contentState.drops.get(d) row.exists.implies(validDrop(row.titleLength, row.bodyLength) and row.revision > 0)}),
    COMMENTS.forall(c => {val row = contentState.comments.get(c) row.exists.implies(row.bodyLength > 0 and row.bodyLength <= 1000)})
  }
  val rejectedRequestsPreserveState = not(contentCommand.accepted).implies(contentState == contentBefore)
  val immutableDropOwnership = DROPS.forall(d =>
    contentBefore.drops.get(d).exists.implies(contentState.drops.get(d).owner == contentBefore.drops.get(d).owner))
  val notificationIsolation = (contentCommand.name == "markRead").implies(
    contentState.notices.filter(n => n.recipient != contentCommand.target) == contentBefore.notices.filter(n => n.recipient != contentCommand.target))
  val authorizedWrites = contentCommand.accepted.implies(all {
    Set("publish", "editDrop", "addComment", "editComment", "deleteComment", "markRead").contains(contentCommand.name)
      .implies(principalAt(contentBefore, contentCommand.device) != 0),
    (contentCommand.name == "editDrop").implies(contentBefore.drops.get(contentCommand.target).owner == principalAt(contentBefore, contentCommand.device)),
    Set("editComment", "deleteComment").contains(contentCommand.name)
      .implies(contentBefore.comments.get(contentCommand.target).owner == principalAt(contentBefore, contentCommand.device))
  })
  val notificationRecipients = contentState.notices.union(contentState.pending).forall(n => {
    val comment = contentState.comments.get(n.comment)
    val author = contentState.drops.get(comment.drop).owner
    val topAuthor = if (comment.parent == 0) comment.owner else contentState.comments.get(comment.parent).owner
    n.actor == comment.owner and (
      (n.kind == "reply_to_comment" and comment.parent != 0 and n.recipient == topAuthor) or
      (n.kind == "comment_on_post" and n.recipient == author and author != topAuthor))
  })
  val inv = referentialIntegrity and validContent and rejectedRequestsPreserveState and immutableDropOwnership
    and notificationIsolation and authorizedWrites and notificationRecipients
  val hasReply = COMMENTS.exists(c => contentState.comments.get(c).exists and contentState.comments.get(c).parent != 0)
  val hasNotification = contentState.notices.size() > 0
  val rejected = not(contentCommand.accepted)
  action step = {
    nondet device = DEVICES.oneOf()
    nondet user = USERS.oneOf()
    nondet d = DROPS.oneOf()
    nondet c = COMMENTS.oneOf()
    nondet p = Set(0, 6).union(COMMENTS.filter(id => contentState.comments.get(id).exists
      and contentState.comments.get(id).drop == d and contentState.comments.get(id).parent == 0)).oneOf()
    nondet title = Set(0, 1, 255, 256).oneOf()
    nondet body = Set(0, 1, 1000, 1001).oneOf()
    nondet code = Set(0, 1, 2).oneOf()
    any {
      login(device, user), oauthFailure(device), logout(device), loseBrowserSession(device), restoreCookie(device),
      tick(1), {nondet boundary = 1.to(20).oneOf() all {boundary == 1, tick(SESSION_TTL)}}, publish(device, d, title, body, code), editDrop(device, d, title, body, code),
      addComment(device, c, d, p, body), editComment(device, c, body), deleteComment(device, c), markRead(device),
      {nondet n = contentState.pending.oneOf() nondet success = Set(true, false).oneOf() deliverNotice(n, success)}
    }
  }
  action stay = all {contentState' = contentState, contentBefore' = contentBefore, contentCommand' = contentCommand}
  action check(p: bool): bool = all { assert(p), contentState' = contentState, contentBefore' = contentBefore, contentCommand' = contentCommand }
  run ownershipTest = init.then(login(1, 1)).then(publish(1, 1, 255, 1, 1)).then(login(2, 2))
    .then(editDrop(2, 1, 1, 1, 2)).then(check(not(contentCommand.accepted) and contentState.drops.get(1).revision == 1 and inv))
  run expiryBoundaryTest = init.then(login(1, 1)).then(tick(SESSION_TTL - 1)).then(check(principal(1) == 1))
    .then(tick(1)).then(publish(1, 1, 1, 1, 0)).then(check(not(contentCommand.accepted) and inv))
  run reloginRevokesOldTokenTest = init.then(login(1, 1)).then(login(2, 1)).then(check(principal(1) == 0 and principal(2) == 1))
  run rememberMeTest = init.then(login(1, 1)).then(loseBrowserSession(1)).then(check(principal(1) == 0))
    .then(restoreCookie(1)).then(check(principal(1) == 1)).then(logout(1)).then(restoreCookie(1)).then(check(principal(1) == 0 and inv))
  run commentCascadeTest = init.then(login(1, 1)).then(publish(1, 1, 1, 1, 0)).then(login(2, 2))
    .then(addComment(2, 1, 1, 0, 1000)).then(login(3, 3)).then(addComment(3, 2, 1, 1, 1))
    .then(check(contentState.pending.size() == 3)).then(addComment(3, 3, 1, 2, 1)).then(check(not(contentCommand.accepted)))
    .then(deleteComment(2, 1)).then(check(not(contentState.comments.get(2).exists) and contentState.pending.size() == 0 and inv))
  run crossDropParentTest = init.then(login(1, 1)).then(publish(1, 1, 1, 1, 0)).then(publish(1, 2, 1, 1, 0))
    .then(addComment(1, 1, 1, 0, 1)).then(addComment(1, 2, 2, 1, 1)).then(check(not(contentCommand.accepted) and inv))
  run notificationFailureTest = init.then(login(1, 1)).then(publish(1, 1, 1, 1, 0)).then(login(2, 2))
    .then(addComment(2, 1, 1, 0, 1)).then(deliverNotice(notice(1, 2, 1, "comment_on_post"), false))
    .then(check(contentState.comments.get(1).exists and contentState.notices.size() == 0 and contentState.pending.size() == 0 and inv))
  run notificationReadIsolationTest = init.then(login(1, 1)).then(publish(1, 1, 1, 1, 0)).then(login(2, 2))
    .then(addComment(2, 1, 1, 0, 1)).then(deliverNotice(notice(1, 2, 1, "comment_on_post"), true))
    .then(markRead(2)).then(check(unread(1).size() == 1)).then(markRead(1)).then(check(unread(1).size() == 0 and inv))
}
