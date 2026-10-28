/// Anonymous sponsor measurement; rendered placements, session dedup and resilient redirect.
module sponsors {
  pure val PLACEMENTS = Set("drop-banner", "drop-sidebar")
  pure val VIEWS = Set(1, 2)
  pure val DROPS = Set(1, 2, 3)
  type View = {drop: int, seen: Set[str], connected: bool, rendered: Set[str]}
  // Persisted type deliberately has no user/IP/user-agent/session/drop identity.
  type Event = {id: int, sponsor: str, placement: str, kind: str, timestamp: int}
  type State = {now: int, views: int -> View, events: Set[Event], nextEvent: int,
    redirect: str, response: int, cacheControl: str}
  pure val initial: State = {now: 0, views: VIEWS.mapBy(_ => {drop: 1, seen: Set(), connected: true, rendered: Set("drop-banner")}),
    events: Set(), nextEvent: 1, redirect: "", response: 0, cacheControl: ""}
  var s: State
  var before: State
  var command: {name: str, excluded: bool}
  action init = all {s' = initial, before' = initial, command' = {name: "init", excluded: false}}
  action move(stateAfter: State, name: str, excluded: bool): bool = all {
    s' = stateAfter, before' = s, command' = {name: name, excluded: excluded}
  }
  pure def destination(placement: str): str = if (placement == "drop-banner")
    "https://www.appsignal.com/?utm_source=elixirdrops&utm_medium=native&utm_campaign=appsignal_q3_2026&utm_content=drop-banner"
    else if (placement == "drop-sidebar")
    "https://www.appsignal.com/?utm_source=elixirdrops&utm_medium=native&utm_campaign=appsignal_q3_2026&utm_content=drop-sidebar" else ""
  action navigate(view: int, drop: int): bool = {
    val old = s.views.get(view)
    move({...s, views: s.views.set(view, {...old, drop: drop, seen: if (old.drop == drop) old.seen else Set()})}, "navigate", false)
  }
  action resize(view: int, wide: bool): bool = move({...s, views: s.views.setBy(view, v => {...v,
    rendered: if (wide) PLACEMENTS else Set("drop-banner")})}, "resize", false)
  action connection(view: int, connected: bool): bool = move({...s, views: s.views.setBy(view, v => {...v, connected: connected})}, "connection", false)
  // delivery=false allows a client retry; DB failure consumes server seen markers.
  action impression(view: int, drop: int, placements: Set[str], qa: bool, bot: bool, delivery: bool, db: bool): bool = {
    val v = s.views.get(view)
    val eligible = v.connected and v.drop == drop and delivery
    val fresh = placements.intersect(v.rendered).intersect(PLACEMENTS).exclude(v.seen)
    val counted = eligible and not(qa) and not(bot) and db
    val ordered = List("drop-banner", "drop-sidebar").select(p => fresh.contains(p))
    val events = if (counted) ordered.indices().map(i => {id: s.nextEvent + i, sponsor: "appsignal",
      placement: ordered.nth(i), kind: "impression", timestamp: s.now}) else Set()
    move({...s, views: if (eligible) s.views.set(view, {...v, seen: v.seen.union(fresh)}) else s.views,
      events: s.events.union(events), nextEvent: s.nextEvent + events.size()}, "impression", qa or bot or not(eligible) or not(db))
  }
  action click(placement: str, qa: bool, bot: bool, isHead: bool, prefetch: bool, db: bool): bool = {
    val known = PLACEMENTS.contains(placement)
    val excluded = not(known) or qa or bot or isHead or prefetch or not(db)
    val event = {id: s.nextEvent, sponsor: "appsignal", placement: placement, kind: "click", timestamp: s.now}
    move({...s, events: if (excluded) s.events else s.events.union(Set(event)),
      nextEvent: s.nextEvent + (if (excluded) 0 else 1), redirect: destination(placement),
      response: if (known) 302 else 404, cacheControl: "private, no-store"}, "click", excluded)
  }
  action tick = move({...s, now: s.now + 1}, "tick", false)
  def count(placement: str, kind: str, from: int, until: int): int =
    s.events.filter(e => e.placement == placement and e.kind == kind and e.timestamp >= from and e.timestamp < until).size()
  def report(placement: str, from: int, until: int): {impressions: int, clicks: int, ctrDefined: bool, ctrBasisPoints: int} = {
    val impressions = count(placement, "impression", from, until)
    val clicks = count(placement, "click", from, until)
    {impressions: impressions, clicks: clicks, ctrDefined: impressions > 0,
      ctrBasisPoints: if (impressions == 0) 0 else (clicks * 10000 + impressions / 2) / impressions}
  }
  val legalEvents = s.events.forall(e => e.sponsor == "appsignal" and PLACEMENTS.contains(e.placement)
    and Set("impression", "click").contains(e.kind) and e.timestamp <= s.now)
  val uniqueIDs = s.events.map(e => e.id).size() == s.events.size()
  val exclusions = command.excluded.implies(s.events == before.events)
  val redirectSafety = (command.name == "click").implies(
    (s.response == 302 and PLACEMENTS.exists(p => s.redirect == destination(p))) or (s.response == 404 and s.redirect == ""))
  val inv = legalEvents and uniqueIDs and exclusions and redirectSafety
  val hasImpression = s.events.exists(e => e.kind == "impression")
  val hasClick = s.events.exists(e => e.kind == "click")
  action step = {
    nondet view = VIEWS.oneOf()
    nondet drop = DROPS.oneOf()
    nondet p = Set("drop-banner", "drop-sidebar", "unknown").oneOf()
    nondet placements = PLACEMENTS.powerset().oneOf()
    nondet qa = Set(true, false).oneOf()
    nondet bot = Set(true, false).oneOf()
    nondet flag = Set(true, false).oneOf()
    nondet db = Set(true, false).oneOf()
    any {navigate(view, drop), resize(view, flag), connection(view, flag), tick,
      impression(view, drop, placements, qa, bot, flag, db), click(p, qa, bot, flag, flag, db)}
  }
  action check(p: bool): bool = all {assert(p), s' = s, before' = before, command' = command}
  run responsiveDedupTest = init.then(impression(1, 1, PLACEMENTS, false, false, true, true))
    .then(impression(1, 1, PLACEMENTS, false, false, true, true)).then(check(s.events.size() == 1))
    .then(resize(1, true)).then(impression(1, 1, PLACEMENTS, false, false, true, true)).then(check(s.events.size() == 2 and inv))
  run navigationResetTest = init.then(impression(1, 1, PLACEMENTS, false, false, true, true)).then(navigate(1, 2))
    .then(impression(1, 1, PLACEMENTS, false, false, true, true)).then(check(s.events.size() == 1))
    .then(impression(1, 2, PLACEMENTS, false, false, true, true)).then(navigate(1, 1))
    .then(impression(1, 1, PLACEMENTS, false, false, true, true)).then(check(s.events.size() == 3 and inv))
  run qaAndBotTest = init.then(impression(1, 1, PLACEMENTS, true, false, true, true))
    .then(click("drop-banner", false, true, false, false, true)).then(check(s.events.size() == 0 and s.response == 302 and inv))
  run headPrefetchTest = init.then(click("drop-banner", false, false, true, false, true))
    .then(click("drop-sidebar", false, false, false, true, true)).then(check(s.events.size() == 0 and s.response == 302 and inv))
  run redirectDespiteDBFailureTest = init.then(click("drop-banner", false, false, false, false, false))
    .then(check(s.events.size() == 0 and s.response == 302 and s.cacheControl == "private, no-store" and inv))
  run dbFailureConsumesSeenTest = init.then(impression(1, 1, PLACEMENTS, false, false, true, false))
    .then(impression(1, 1, PLACEMENTS, false, false, true, true)).then(check(s.events.size() == 0 and inv))
  run deliveryFailureRetryTest = init.then(impression(1, 1, PLACEMENTS, false, false, false, true))
    .then(impression(1, 1, PLACEMENTS, false, false, true, true)).then(check(s.events.size() == 1 and inv))
  run reportBoundaryTest = init.then(impression(1, 1, PLACEMENTS, false, false, true, true)).then(tick)
    .then(click("drop-banner", false, false, false, false, true)).then(check(report("drop-banner", 0, 1).clicks == 0
      and report("drop-banner", 0, 2).ctrBasisPoints == 10000 and not(report("drop-sidebar", 0, 2).ctrDefined) and inv))
  run unknownPlacementTest = init.then(click("https://evil.invalid", false, false, false, false, true))
    .then(check(s.response == 404 and s.redirect == "" and inv))
}
