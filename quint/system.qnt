/// Composition checks persistence admission against asynchronous content projections.
module system {
  import app as Content from "./app"
  import delivery as Delivery from "./delivery"
  pure val IDS = Set(1, 2, 3)
  action init = all {Content::init, Delivery::init}
  action publish(device: int, d: int, titleLength: int, bodyLength: int, code: int): bool = {
    val admitted = Content::principal(device) != 0 and not(Content::contentState.drops.get(d).exists)
      and Content::validDrop(titleLength, bodyLength)
    all {
      Content::publish(device, d, titleLength, bodyLength, code),
      if (admitted) Delivery::save(d, code) else Delivery::stay
    }
  }
  action edit(device: int, d: int, titleLength: int, bodyLength: int, code: int): bool = {
    val row = Content::contentState.drops.get(d)
    val admitted = Content::principal(device) != 0 and row.exists and row.owner == Content::principal(device)
      and Content::validDrop(titleLength, bodyLength)
    all {
      Content::editDrop(device, d, titleLength, bodyLength, code),
      if (admitted) Delivery::save(d, code) else Delivery::stay
    }
  }
  // Independent schedulers interleave; rejected saves never enqueue image work.
  action step = {
    nondet device = Content::DEVICES.oneOf()
    nondet user = Content::USERS.oneOf()
    nondet d = IDS.oneOf()
    nondet c = Content::COMMENTS.oneOf()
    nondet parent = Set(0, 1, 2, 3, 4, 5, 6).oneOf()
    nondet code = Set(0, 1, 2).oneOf()
    nondet titleLength = Set(0, 1, 255, 256).oneOf()
    nondet bodyLength = Set(0, 1, 1000, 1001).oneOf()
    any {
      publish(device, d, titleLength, bodyLength, code), edit(device, d, titleLength, bodyLength, code),
      all {
        any {Content::login(device, user), Content::logout(device), Content::oauthFailure(device),
          Content::tick(1), {nondet boundary = 1.to(20).oneOf() all {boundary == 1, Content::tick(Content::SESSION_TTL)}}, Content::restoreCookie(device), Content::loseBrowserSession(device),
          Content::addComment(device, c, d, parent, bodyLength), Content::editComment(device, c, bodyLength),
          Content::deleteComment(device, c), Content::markRead(device),
          {nondet n = Content::contentState.pending.oneOf() nondet success = Set(true, false).oneOf() Content::deliverNotice(n, success)}},
        Delivery::stay
      },
      all {
        Content::stay,
        any {Delivery::readMarkdown(d), Delivery::readMarkdown(0), Delivery::tick(300),
          Delivery::beginSitemap, Delivery::finishSitemap, Delivery::failSitemap,
          {nondet j = Delivery::deliveryState.jobs.oneOf() any {Delivery::startJob(j), Delivery::upload(j, true), Delivery::upload(j, false),
            Delivery::finish(j), Delivery::failJob(j), Delivery::progress(j, 90)}}}
      }
    }
  }
  val contentProjection = IDS.forall(d => {
    val content = Content::contentState.drops.get(d)
    val projection = Delivery::deliveryState.rows.get(d)
    content.exists == projection.exists and content.code == projection.code and content.revision == projection.revision
  })
  val jobsReferToPublishedContent = Delivery::deliveryState.jobs.forall(j => Content::contentState.drops.get(j.drop).exists)
  val inv = Content::inv and Delivery::inv and contentProjection and jobsReferToPublishedContent
  val hasContent = IDS.exists(d => Content::contentState.drops.get(d).exists)
  val hasImage = Delivery::completedImage
  action check(p: bool): bool = all {assert(p), Content::stay, Delivery::stay}
  run rejectedPublishHasNoJobTest = init.then(publish(1, 1, 1, 1, 1))
    .then(check(Delivery::deliveryState.jobs.size() == 0 and inv))
  run rejectedEditHasNoSideEffectTest = init.then(all {Content::login(1, 1), Delivery::stay})
    .then(publish(1, 1, 1, 1, 1)).then(all {Content::login(2, 2), Delivery::stay})
    .then(edit(2, 1, 1, 1, 2)).then(check(Delivery::deliveryState.jobs.size() == 1 and Delivery::deliveryState.rows.get(1).code == 1 and inv))
  run editedProjectionTest = init.then(all {Content::login(1, 1), Delivery::stay}).then(publish(1, 1, 1, 1, 0))
    .then(edit(1, 1, 1, 1, 1)).then(check(Delivery::deliveryState.rows.get(1).status == "pending" and Delivery::deliveryState.jobs.size() == 1 and inv))
}
