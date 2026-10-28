/// Content projections, screenshot races, retry exhaustion and atomic sitemap replacement.
module delivery {
  pure val DROPS = Set(1, 2, 3)
  type Row = { exists: bool, revision: int, code: int, imageCode: int, status: str, meta: bool, internal: bool }
  type Job = { id: int, drop: int, code: int, phase: str, attempt: int, progress: int, meta: bool, internal: bool }
  type Cache = { revision: int, expires: int }
  type State = { now: int, version: int, rows: int -> Row, jobs: Set[Job], nextJob: int,
    cache: int -> Cache, sitemap: Set[int], sitemapVersion: int, sitemapPhase: str,
    sitemapSnapshot: Set[int], snapshotVersion: int, sitemapAttempt: int, sitemapQueued: bool }
  pure val emptyRow: Row = {exists: false, revision: 0, code: 0, imageCode: 0, status: "skipped", meta: false, internal: false}
  pure val emptyCache: Cache = {revision: -1, expires: 0}
  pure val initial: State = {now: 0, version: 0, rows: DROPS.mapBy(_ => emptyRow), jobs: Set(), nextJob: 1,
    cache: Set(0, 1, 2, 3).mapBy(_ => emptyCache), sitemap: Set(), sitemapVersion: 0,
    sitemapPhase: "idle", sitemapSnapshot: Set(), snapshotVersion: 0, sitemapAttempt: 0, sitemapQueued: false}
  var deliveryState: State
  var deliveryBefore: State
  var deliveryCommand: {name: str, target: int}
  action init = all {deliveryState' = initial, deliveryBefore' = initial, deliveryCommand' = {name: "init", target: 0}}
  action move(stateAfter: State, name: str, target: int): bool = all {
    deliveryBefore' = deliveryState, deliveryState' = stateAfter, deliveryCommand' = {name: name, target: target}
  }
  pure def newJob(id: int, d: int, code: int): Job =
    {id: id, drop: d, code: code, phase: "queued", attempt: 0, progress: 0, meta: false, internal: false}
  action saveWithEnqueue(d: int, code: int, enqueued: bool): bool = {
    val old = deliveryState.rows.get(d)
    val needsJob = code != 0 and (not(old.exists) or code != old.code)
    val row = {exists: true, revision: old.revision + 1, code: code,
      imageCode: if (needsJob or code == 0) 0 else old.imageCode,
      status: if (code == 0) "skipped" else if (needsJob) "pending" else old.status,
      meta: if (needsJob or code == 0) false else old.meta,
      internal: if (needsJob or code == 0) false else old.internal}
    move({...deliveryState, version: deliveryState.version + 1, rows: deliveryState.rows.set(d, row),
      cache: Set(0, 1, 2, 3).mapBy(_ => emptyCache),
      jobs: if (needsJob and enqueued) deliveryState.jobs.union(Set(newJob(deliveryState.nextJob, d, code))) else deliveryState.jobs,
      nextJob: if (needsJob and enqueued) deliveryState.nextJob + 1 else deliveryState.nextJob,
      sitemapQueued: deliveryState.sitemapQueued or (not(needsJob) and enqueued)}, "save", d)
  }
  action save(d: int, code: int): bool = saveWithEnqueue(d, code, true)
  action startJob(j: Job): bool = all {
    deliveryState.jobs.contains(j), j.phase == "queued", j.attempt < 5,
    move({...deliveryState, jobs: deliveryState.jobs.exclude(Set(j)).union(Set({...j, phase: "running", attempt: j.attempt + 1,
      progress: 50, meta: false, internal: false}))}, "startJob", j.drop)
  }
  action progress(j: Job, amount: int): bool = all {
    deliveryState.jobs.contains(j), j.phase == "running", amount >= j.progress, amount < 100,
    move({...deliveryState, jobs: deliveryState.jobs.exclude(Set(j)).union(Set({...j, progress: amount}))}, "progress", j.drop)
  }
  action upload(j: Job, meta: bool): bool = all {
    deliveryState.jobs.contains(j), j.phase == "running",
    move({...deliveryState, jobs: deliveryState.jobs.exclude(Set(j)).union(Set(if (meta) {...j, meta: true} else {...j, internal: true}))},
      "upload", j.drop)
  }
  // A stale worker must not replace a newer code image. Current source lacks this fence (G04).
  action finish(j: Job): bool = all {
    deliveryState.jobs.contains(j), j.phase == "running", j.meta and j.internal,
    {
      val row = deliveryState.rows.get(j.drop)
      val current = row.code == j.code
      move({...deliveryState, jobs: deliveryState.jobs.exclude(Set(j)).union(Set({...j, phase: "completed", progress: 100})),
        rows: if (current) deliveryState.rows.set(j.drop, {...row, status: "completed", imageCode: j.code, meta: true, internal: true}) else deliveryState.rows,
        cache: if (current) Set(0, 1, 2, 3).mapBy(_ => emptyCache) else deliveryState.cache,
        version: if (current) deliveryState.version + 1 else deliveryState.version, sitemapQueued: deliveryState.sitemapQueued or current}, "finish", j.drop)
    }
  }
  action failJob(j: Job): bool = all {
    deliveryState.jobs.contains(j), j.phase == "running",
    {
      val row = deliveryState.rows.get(j.drop)
      val current = row.code == j.code
      move({...deliveryState, jobs: deliveryState.jobs.exclude(Set(j)).union(Set({...j, phase: if (j.attempt < 5) "queued" else "discarded"})),
        rows: if (current) deliveryState.rows.set(j.drop, {...row, status: "failed", imageCode: 0, meta: false, internal: false}) else deliveryState.rows,
        cache: if (current) Set(0, 1, 2, 3).mapBy(_ => emptyCache) else deliveryState.cache}, "failJob", j.drop)
    }
  }
  def revision(key: int): int = if (key == 0) deliveryState.version else deliveryState.rows.get(key).revision
  def cacheHit(key: int): bool = deliveryState.cache.get(key).revision >= 0 and deliveryState.now < deliveryState.cache.get(key).expires
  action readMarkdown(key: int): bool = all {
    key == 0 or deliveryState.rows.get(key).exists,
    move({...deliveryState, cache: if (cacheHit(key)) deliveryState.cache else deliveryState.cache.set(key, {revision: revision(key), expires: deliveryState.now + 300})},
      "readMarkdown", key)
  }
  action tick(seconds: int): bool = move({...deliveryState, now: deliveryState.now + seconds}, "tick", 0)
  action beginSitemap = all {
    deliveryState.sitemapQueued, deliveryState.sitemapPhase == "idle",
    move({...deliveryState, sitemapPhase: "writing", sitemapSnapshot: DROPS.filter(d => deliveryState.rows.get(d).exists),
      snapshotVersion: deliveryState.version, sitemapQueued: false, sitemapAttempt: 1}, "beginSitemap", 0)
  }
  action finishSitemap = all {
    deliveryState.sitemapPhase == "writing",
    move({...deliveryState, sitemap: deliveryState.sitemapSnapshot, sitemapVersion: deliveryState.snapshotVersion, sitemapPhase: "idle"}, "finishSitemap", 0)
  }
  action failSitemap = all {
    deliveryState.sitemapPhase == "writing",
    move({...deliveryState, sitemapPhase: if (deliveryState.sitemapAttempt < 3) "writing" else "idle",
      sitemapAttempt: deliveryState.sitemapAttempt + 1}, "failSitemap", 0)
  }
  val imageIntegrity = DROPS.forall(d => {
    val row = deliveryState.rows.get(d)
    all {
      (row.status == "completed").implies(row.code != 0 and row.imageCode == row.code and row.meta and row.internal),
      (row.status == "skipped" or row.status == "failed" or row.status == "pending").implies(not(row.meta) and not(row.internal))
    }
  })
  val cacheFreshness = Set(0, 1, 2, 3).forall(key => cacheHit(key).implies(deliveryState.cache.get(key).revision == revision(key)))
  val retryBound = deliveryState.jobs.forall(j => j.attempt >= 0 and j.attempt <= 5 and j.progress >= 0 and j.progress <= 100
    and (j.phase == "discarded").implies(j.attempt == 5))
  val sitemapIntegrity = deliveryState.sitemap.subseteq(DROPS.filter(d => deliveryState.rows.get(d).exists)) and deliveryState.sitemapVersion <= deliveryState.version
  val atomicSitemap = (deliveryCommand.name != "finishSitemap").implies(deliveryState.sitemap == deliveryBefore.sitemap)
  val inv = imageIntegrity and cacheFreshness and retryBound and sitemapIntegrity and atomicSitemap
  val completedImage = DROPS.exists(d => deliveryState.rows.get(d).status == "completed")
  val failedImage = DROPS.exists(d => deliveryState.rows.get(d).status == "failed")
  val staleJob = deliveryState.jobs.exists(j => j.phase == "running" and j.code != deliveryState.rows.get(j.drop).code)
  action step = {
    nondet d = DROPS.oneOf()
    nondet code = Set(0, 1, 2).oneOf()
    nondet key = Set(0, 1, 2, 3).oneOf()
    any {
      save(d, code), saveWithEnqueue(d, code, false), readMarkdown(key), tick(1), tick(300), beginSitemap, finishSitemap, failSitemap,
      {nondet j = deliveryState.jobs.oneOf() any {startJob(j), upload(j, true), upload(j, false), finish(j), failJob(j), progress(j, 90)}}
    }
  }
  action stay = all {deliveryState' = deliveryState, deliveryBefore' = deliveryBefore, deliveryCommand' = deliveryCommand}
  action check(p: bool): bool = all {assert(p), deliveryState' = deliveryState, deliveryBefore' = deliveryBefore, deliveryCommand' = deliveryCommand}
  action startFirst = startJob(newJob(1, 1, 1))
  pure def running(id: int, d: int, code: int, attempt: int, meta: bool, internal: bool): Job =
    {id: id, drop: d, code: code, phase: "running", attempt: attempt, progress: 50, meta: meta, internal: internal}
  run enqueueFailureTest = init.then(saveWithEnqueue(1, 1, false))
    .then(check(deliveryState.rows.get(1).exists and deliveryState.rows.get(1).status == "pending" and deliveryState.jobs.size() == 0 and inv))
  run successfulImageTest = init.then(save(1, 1)).then(startFirst).then(upload(running(1, 1, 1, 1, false, false), true))
    .then(upload(running(1, 1, 1, 1, true, false), false)).then(finish(running(1, 1, 1, 1, true, true)))
    .then(check(deliveryState.rows.get(1).status == "completed" and deliveryState.sitemapQueued and inv))
  run staleCompletionTest = init.then(save(1, 1)).then(startFirst).then(save(1, 2))
    .then(upload(running(1, 1, 1, 1, false, false), true)).then(upload(running(1, 1, 1, 1, true, false), false))
    .then(finish(running(1, 1, 1, 1, true, true))).then(check(deliveryState.rows.get(1).status == "pending" and inv))
  run unchangedFailedCodeTest = init.then(save(1, 1)).then(startFirst).then(failJob(running(1, 1, 1, 1, false, false)))
    .then(save(1, 1)).then(check(deliveryState.rows.get(1).status == "failed" and inv))
  run cacheBoundaryTest = init.then(save(1, 0)).then(readMarkdown(1)).then(tick(299)).then(check(cacheHit(1)))
    .then(tick(1)).then(check(not(cacheHit(1)))).then(readMarkdown(1)).then(save(1, 0)).then(check(not(cacheHit(1)) and inv))
  run atomicSitemapTest = init.then(save(1, 0)).then(beginSitemap).then(failSitemap)
    .then(check(deliveryState.sitemap.size() == 0)).then(finishSitemap).then(check(deliveryState.sitemap == Set(1) and inv))
  run partialUploadFailureTest = init.then(save(1, 1)).then(startFirst).then(upload(running(1, 1, 1, 1, false, false), true))
    .then(failJob(running(1, 1, 1, 1, true, false))).then(check(deliveryState.rows.get(1).status == "failed" and not(deliveryState.rows.get(1).meta) and inv))
  run retryExhaustionTest = init.then(save(1, 1)).then(5.reps(i => {
    val j = {id: 1, drop: 1, code: 1, phase: "queued", attempt: i, progress: if (i == 0) 0 else 50, meta: false, internal: false}
    startJob(j).then(failJob(running(1, 1, 1, i + 1, false, false)))
  })).then(check(deliveryState.jobs.forall(j => j.phase == "discarded" and j.attempt == 5) and inv))
}
