/// HTTP access and representation boundary; details stay in ../spec/http.md.
module http {
  pure val ROUTES = Set("home", "archive", "indexMd", "drop", "dropMd", "profile", "new", "edit", "snippet", "health", "devAuth", "unknown")
  type Request = {route: str, signedIn: bool, owner: bool, exists: bool, code: bool,
    basicAuth: bool, db: bool, dev: bool, validType: bool}
  type Response = {status: int, format: str, canonical: str, cache: str, challenge: bool}
  pure def response(status: int, format: str, canonical: str, cache: str, challenge: bool): Response =
    {status: status, format: format, canonical: canonical, cache: cache, challenge: challenge}
  pure val missing = response(404, "plain", "", "", false)
  pure val homeRedirect = response(302, "html", "", "", false)
  pure def serve(r: Request): Response =
    if (r.route == "home") response(200, "html", "home", "", false)
    else if (r.route == "archive") response(200, "html", "archive", "", false)
    else if (r.route == "indexMd") response(200, "markdown", "archive", "public, max-age=300", false)
    else if (r.route == "drop") if (r.exists) response(200, "html", "drop", "", false) else homeRedirect
    else if (r.route == "dropMd") if (r.exists) response(200, "markdown", "drop", "public, max-age=300", false) else response(404, "plain", "drop", "", false)
    else if (r.route == "profile") if (r.signedIn) response(200, "html", "", "", false) else homeRedirect
    else if (r.route == "new") if (r.signedIn) response(200, "html", "", "", false) else homeRedirect
    else if (r.route == "edit") if (r.signedIn and r.owner and r.exists) response(200, "html", "", "", false) else homeRedirect
    else if (r.route == "snippet") if (not(r.basicAuth)) response(401, "plain", "", "", true)
      else if (not(r.validType)) response(400, "plain", "", "", false)
      else if (r.exists and r.code) response(200, "html", "", "", false) else missing
    else if (r.route == "health") if (r.db) response(200, "json", "", "", false) else response(500, "json", "", "", false)
    else if (r.route == "devAuth") if (r.dev and r.exists) homeRedirect else missing
    else missing
  pure def markdownIntercept(shortIDBytes: int, extension: str): bool = shortIDBytes == 8 and extension == ".md"
  pure val defaultRequest: Request = {route: "home", signedIn: false, owner: false, exists: true,
    code: true, basicAuth: false, db: true, dev: false, validType: true}
  var request: Request
  var result: Response
  action init = all {request' = defaultRequest, result' = serve(defaultRequest)}
  action visit(r: Request): bool = all {request' = r, result' = serve(r)}
  val protectedRoutes = Set("profile", "new", "edit")
  val authentication = (protectedRoutes.contains(request.route) and not(request.signedIn)).implies(result.status == 302)
  val ownership = (request.route == "edit" and not(request.owner)).implies(result.status != 200)
  val snippetAuthentication = (request.route == "snippet" and not(request.basicAuth)).implies(result.status == 401 and result.challenge)
  val noPrivateCanonical = Set("profile", "new", "edit", "snippet", "health", "devAuth", "unknown").contains(request.route).implies(result.canonical == "")
  val markdownHeaders = (result.format == "markdown").implies(result.cache == "public, max-age=300" and result.canonical != "")
  val productionDevRoutes = (request.route == "devAuth" and not(request.dev)).implies(result.status == 404)
  val inv = authentication and ownership and snippetAuthentication and noPrivateCanonical and markdownHeaders and productionDevRoutes
  action step = {
    nondet route = ROUTES.oneOf()
    nondet signedIn = Set(true, false).oneOf()
    nondet owner = Set(true, false).oneOf()
    nondet found = Set(true, false).oneOf()
    nondet code = Set(true, false).oneOf()
    nondet basicAuth = Set(true, false).oneOf()
    nondet db = Set(true, false).oneOf()
    nondet dev = Set(true, false).oneOf()
    nondet validType = Set(true, false).oneOf()
    visit({route: route, signedIn: signedIn, owner: owner, exists: found, code: code, basicAuth: basicAuth,
      db: db, dev: dev, validType: validType})
  }
  action check(p: bool): bool = all {assert(p), request' = request, result' = result}
  run privateRoutesTest = init.then(visit({...defaultRequest, route: "profile"})).then(check(result.status == 302 and inv))
    .then(visit({...defaultRequest, route: "edit", signedIn: true, owner: false})).then(check(result.status == 302 and inv))
  run markdownCanonicalTest = init.then(visit({...defaultRequest, route: "indexMd"})).then(check(result.canonical == "archive" and inv))
    .then(visit({...defaultRequest, route: "dropMd"})).then(check(result.canonical == "drop" and inv))
  run markdownMissingTest = init.then(visit({...defaultRequest, route: "dropMd", exists: false})).then(check(result.status == 404 and inv))
  run snippetChallengeTest = init.then(visit({...defaultRequest, route: "snippet"})).then(check(result.status == 401 and inv))
    .then(visit({...defaultRequest, route: "snippet", basicAuth: true})).then(check(result.status == 200 and inv))
  run invalidSnippetTypeTest = init.then(visit({...defaultRequest, route: "snippet", basicAuth: true, validType: false}))
    .then(check(result.status == 400 and inv))
  run healthDBFailureTest = init.then(visit({...defaultRequest, route: "health", db: false})).then(check(result.status == 500 and inv))
  run productionDevAuthTest = init.then(visit({...defaultRequest, route: "devAuth"})).then(check(result.status == 404 and inv))
  run exactMarkdownPatternTest = init.then(check(markdownIntercept(8, ".md") and not(markdownIntercept(7, ".md")) and not(markdownIntercept(9, ".md"))))
}
