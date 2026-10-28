/// Public timeline, profile isolation, search/suggestions, asynchronous page delivery and layout.
module discovery {
  pure val USERS = Set(1, 2, 3)
  pure val IDS = Set(1, 2, 3, 4, 5, 6)
  pure val QUERIES = List(1, 2, 3, 4, 5, 6)
  pure val newest = List(6, 5, 4, 3, 2, 1)
  // Deliberate relevance ties: 1/2, 3/4, 5/6. Secondary ordering retains all ties.
  pure val ranked = List(2, 1, 4, 3, 6, 5)
  pure def owner(d: int): int = (d % 3) + 1
  pure def take(xs: List[int], n: int): List[int] = xs.slice(0, if (n < xs.length()) n else xs.length())
  pure def unique(xs: List[int]): List[int] = xs.foldl(List(), (acc, x) => if (acc.indices().exists(i => acc.nth(i) == x)) acc else acc.append(x))
  pure def columns(width: int): int = if (width <= 480) 1 else if (width <= 768) 2 else if (width <= 1400) 3 else if (width <= 1800) 4 else 5
  pure def batchSize(width: int, height: int): int = {
    val cols = columns(width)
    val rows = if (height < 550) 1 else (height - 200) / 350
    val visible = if (cols * rows > cols * 2) cols * rows else cols * 2
    val raw = visible + cols
    if (raw < 6) 6 else if (raw > 40) 40 else raw
  }
  type Suggestion = {query: int, kind: str}
  type Request = {epoch: int, offset: int, items: List[int]}
  type State = {public: Set[int], ready: Set[int], user: int, profile: bool, search: bool,
    epoch: int, snapshot: List[int], visible: List[int], pageSize: int, end: bool, loading: bool,
    requests: Set[Request], pendingLayout: Set[int], positioned: Set[int], managed: bool,
    connected: bool, newDrops: bool, dismissed: bool, overlay: bool,
    histories: int -> List[int], popular: int -> int, suggestions: List[Suggestion]}
  pure val initial: State = {public: IDS, ready: IDS, user: 0, profile: false, search: false,
    epoch: 0, snapshot: newest, visible: List(), pageSize: 2, end: false, loading: false,
    requests: Set(), pendingLayout: Set(), positioned: Set(), managed: true,
    connected: true, newDrops: false, dismissed: false, overlay: false,
    histories: USERS.mapBy(_ => List()), popular: IDS.mapBy(_ => 0), suggestions: List()}
  var s: State
  var before: State
  var command: str
  var actor: int
  action init = all {s' = initial, before' = initial, command' = "init", actor' = 0}
  action move(stateAfter: State, name: str): bool = all {s' = stateAfter, before' = s, command' = name, actor' = 0}
  def collection(user: int, profile: bool, search: bool): List[int] =
    (if (search) ranked else newest).select(d => s.public.contains(d) and
      (if (profile) owner(d) == user else s.ready.contains(d)))
  action navigate(user: int, profile: bool, search: bool): bool = {
    val allowed = not(profile) or user.in(USERS)
    move(if (allowed) {...s, user: user, profile: profile, search: search, epoch: s.epoch + 1,
      snapshot: collection(user, profile, search), visible: List(), end: false, loading: false,
      pendingLayout: Set(), positioned: Set(), suggestions: List(), overlay: false, newDrops: false} else s, "navigate")
  }
  action loadMore = all {
    s.connected, not(s.loading), not(s.end),
    {
      val offset = s.visible.length()
      val upper = if (offset + s.pageSize < s.snapshot.length()) offset + s.pageSize else s.snapshot.length()
      move({...s, loading: true, requests: s.requests.union(Set({epoch: s.epoch, offset: offset,
        items: s.snapshot.slice(offset, upper)}))}, "loadMore")
    }
  }
  action receivePage(r: Request): bool = all {
    s.requests.contains(r),
    {
      val current = r.epoch == s.epoch and r.offset == s.visible.length()
      move(if (current) {...s, requests: s.requests.exclude(Set(r)), loading: false,
        visible: s.visible.concat(r.items), pendingLayout: s.pendingLayout.union(r.items.indices().map(i => r.items.nth(i))),
        end: r.items.length() < s.pageSize} else {...s, requests: s.requests.exclude(Set(r))}, "receivePage")
    }
  }
  action layout = move({...s, positioned: s.positioned.union(s.pendingLayout), pendingLayout: Set()}, "layout")
  action destroyLayout = move({...s, managed: false, pendingLayout: Set()}, "destroyLayout")
  action reconnect = move({...s, connected: true, managed: true,
    pendingLayout: s.visible.indices().map(i => s.visible.nth(i)).exclude(s.positioned)}, "reconnect")
  action disconnect = move({...s, connected: false}, "disconnect")
  action publishReady(d: int): bool = move({...s, ready: s.ready.union(Set(d)), newDrops: true}, "publishReady")
  action setPending(d: int): bool = move({...s, ready: s.ready.exclude(Set(d))}, "setPending")
  action dismissWelcome = move({...s, dismissed: true}, "dismissWelcome")
  action remount = move({...s, overlay: false}, "remount")
  action toggleOverlay = move({...s, overlay: not(s.overlay)}, "toggleOverlay")
  // Query IDs stand for normalized nonblank queries; 0 stands for blank input.
  action track(user: int, query: int, historySuccess: bool, popularSuccess: bool): bool = {
    val histories = if (user.in(USERS) and query != 0 and historySuccess)
      s.histories.setBy(user, xs => List(query).concat(xs)) else s.histories
    val popular = if (query != 0 and popularSuccess) s.popular.setBy(query, n => n + 1) else s.popular
    move({...s, histories: histories, popular: popular}, "track")
  }
  action deleteHistory(user: int, rowOwner: int, query: int): bool = all {
    s' = if (user.in(USERS) and user == rowOwner) {...s, histories: s.histories.setBy(user, xs => xs.select(q => q != query))} else s,
    before' = s, command' = "deleteHistory", actor' = user
  }
  def history(user: int): List[int] = if (user.in(USERS)) take(unique(s.histories.get(user)), 100) else List()
  def popularOrder(matching: Set[int]): List[int] = QUERIES.select(q => matching.contains(q) and s.popular.get(q) > 0)
    .foldl(List(), (acc, q) => {
      val index = acc.indices().filter(i => s.popular.get(q) > s.popular.get(acc.nth(i)))
        .fold(acc.length(), (smallest, i) => if (i < smallest) i else smallest)
      acc.slice(0, index).concat(List(q)).concat(acc.slice(index, acc.length()))
    })
  def suggestions(user: int, matching: Set[int]): List[Suggestion] = {
    val hs = take(history(user).select(q => matching.contains(q)), 2)
    val ps = take(popularOrder(matching).select(q => not(hs.indices().exists(i => hs.nth(i) == q))), if (user == 0) 5 else 3)
    hs.foldl(List(), (acc, q) => acc.append({query: q, kind: "history"})).concat(ps.foldl(List(), (acc, q) => acc.append({query: q, kind: "popular"})))
  }
  action suggest(user: int, matching: Set[int]): bool = move({...s, suggestions: suggestions(user, matching)}, "suggest")
  val noDuplicates = s.visible.indices().map(i => s.visible.nth(i)).size() == s.visible.length()
  val correctPagePrefix = s.visible == take(s.snapshot, s.visible.length())
  val profileIsolation = s.profile.implies(s.visible.indices().forall(i => owner(s.visible.nth(i)) == s.user))
  val layoutSafety = s.managed.implies(s.visible.indices().forall(i => s.positioned.contains(s.visible.nth(i)) or s.pendingLayout.contains(s.visible.nth(i))))
  val suggestionIntegrity = all {
    s.suggestions.length() <= 5,
    s.suggestions.indices().map(i => s.suggestions.nth(i).query).size() == s.suggestions.length(),
    s.suggestions.select(x => x.kind == "history").length() <= 2
  }
  val historyIsolation = (command == "deleteHistory").implies(USERS.forall(u =>
    (u != actor).implies(s.histories.get(u) == before.histories.get(u))))
  val welcomePersistence = before.dismissed.implies(s.dismissed)
  val inv = noDuplicates and correctPagePrefix and profileIsolation and layoutSafety and suggestionIntegrity and historyIsolation and welcomePersistence
  val hasPages = s.visible.length() >= 4
  val hasSuggestions = s.suggestions.length() > 0
  action step = {
    nondet user = Set(0, 1, 2, 3).oneOf()
    nondet d = IDS.oneOf()
    nondet query = Set(0, 1, 2, 3, 4, 5, 6).oneOf()
    nondet flag = Set(true, false).oneOf()
    nondet matching = IDS.powerset().oneOf()
    any {
      navigate(user, flag, flag), loadMore, {nondet r = s.requests.oneOf() receivePage(r)},
      layout, destroyLayout, reconnect, disconnect, publishReady(d), setPending(d), dismissWelcome, remount, toggleOverlay,
      track(user, query, flag, flag), deleteHistory(user, 1, query), suggest(user, matching)
    }
  }
  action check(p: bool): bool = all {assert(p), s' = s, before' = before, command' = command, actor' = actor}
  run tiedRankingPaginationTest = init.then(navigate(0, false, true)).then(loadMore)
    .then(receivePage({epoch: 1, offset: 0, items: List(2, 1)})).then(loadMore)
    .then(receivePage({epoch: 1, offset: 2, items: List(4, 3)})).then(loadMore)
    .then(receivePage({epoch: 1, offset: 4, items: List(6, 5)})).then(loadMore)
    .then(receivePage({epoch: 1, offset: 6, items: List()})).then(check(s.visible == ranked and s.end and inv))
  run stalePageTest = init.then(loadMore).then(navigate(1, true, false))
    .then(receivePage({epoch: 0, offset: 0, items: List(6, 5)})).then(check(s.visible.length() == 0 and inv))
  run suggestionDedupTest = init.then(track(1, 1, true, true)).then(track(1, 1, true, true)).then(track(1, 2, true, true))
    .then(suggest(1, IDS)).then(check(s.suggestions == List({query: 2, kind: "history"}, {query: 1, kind: "history"}) and inv))
  run anonymousHistoryTest = init.then(track(1, 1, true, true)).then(suggest(0, IDS))
    .then(check(s.suggestions == List({query: 1, kind: "popular"}) and inv))
  run deleteAllQueryOccurrencesTest = init.then(track(1, 1, true, true)).then(track(1, 1, true, true))
    .then(track(2, 1, true, true)).then(deleteHistory(2, 1, 1)).then(check(s.histories.get(1).length() == 2))
    .then(deleteHistory(1, 1, 1)).then(check(s.histories.get(1).length() == 0 and s.histories.get(2).length() == 1 and inv))
  run batchBoundariesTest = init.then(check(columns(480) == 1 and columns(481) == 2 and columns(768) == 2 and columns(769) == 3
    and columns(1401) == 4 and columns(1801) == 5 and batchSize(320, 200) == 6 and batchSize(2000, 10000) == 40))
  run welcomeDismissalTest = init.then(dismissWelcome).then(disconnect).then(reconnect).then(remount).then(check(s.dismissed and inv))
  run newDropRefreshTest = init.then(setPending(6)).then(navigate(0, false, false)).then(publishReady(6))
    .then(check(s.newDrops and s.snapshot == List(5, 4, 3, 2, 1))).then(navigate(0, false, false))
    .then(check(not(s.newDrops) and s.snapshot == newest and inv))
}
