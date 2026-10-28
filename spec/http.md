# HTTP and application boundary

Executable owner: [http.qnt](../quint/http.qnt). Dynamic route parsing, redirects,
CSRF, secure headers and cookie cryptography still require Phoenix/Plug tests.

| Surface                                      | Access and behavior                                                           | Representation / canonical                                        |
| -------------------------------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `/` and `/?q=...`                            | Public ready-state timeline/search                                            | HTML; self-canonical `/`                                          |
| `/archive`                                   | Every saved Drop, ordinary links and month groups                             | HTML; self-canonical `/archive`                                   |
| `/index.md`                                  | Full collection and summaries                                                 | Markdown; Link canonical `/archive`; public max-age=300; nosniff  |
| `/d/:short_id`                               | Public saved Drop with discussion; missing currently attempts navigation home | HTML; self-canonical detail URL                                   |
| `/d/:short_id.md`                            | Exactly eight short-ID bytes followed by `.md`; missing 404                   | Markdown; Link canonical HTML detail; public max-age=300; nosniff |
| `/profile`                                   | Authenticated author's Drops and search only                                  | HTML; no inherited homepage canonical                             |
| `/drops/new`                                 | Authenticated publishing form                                                 | HTML; no inherited homepage canonical                             |
| `/drops/:short_id/edit`                      | Existing author's Drop only; otherwise error/redirect home                    | HTML; no inherited homepage canonical                             |
| `/auth/:provider`                            | Supported GitHub OAuth initiation, preserves requested return path            | Provider redirect; trusted OAuth integration                      |
| `/auth/:provider/callback`                   | Valid profile → identity/session; failure → home                              | Session renewal and redirect                                      |
| `/auth/logout`                               | Revoke session token, clear cookie/session, disconnect socket                 | Home redirect                                                     |
| `/d/:UUID/code_snippet`                      | Basic auth required; first code block; internal default or `type=meta`        | Standalone HTML; 401 challenge, missing/code-free 404             |
| `/go/appsignal/:placement`                   | Known placement only; record eligible click without blocking redirect         | Fixed 302; private, no-store; unknown 404                         |
| `/health`                                    | Database connection probe; current node/host summary                          | JSON 200 on success; failure 500                                  |
| `/dev/auth/:user_id`                         | Mounted only with compile-time dev routes; existing test/local user           | Auth bypass redirect; unavailable in production                   |
| `/dev/dashboard`, `/dev/mailbox`             | Development-only utilities                                                    | Platform-owned HTML; unavailable in production                    |
| `/sitemap.xml`, `/robots.txt`, static assets | Endpoint static serving; existence/deployment controls availability           | XML/text/assets, not database mutations                           |
| Other paths                                  | Router miss                                                                   | Normal 404                                                        |

**H01 (baseline).** Public read routes do not require a GitHub session. Authentication
is separate from snippet Basic auth. Private pages require authentication both in
HTTP admission and LiveView mount. Cookies/session IDs must not make an unknown or
revoked stored token valid. Browser writes use the framework's authenticated/CSRF
boundary; the domain model separately enforces ownership at command admission.

**H02 (baseline intent).** Missing content, invalid IDs and malformed input should
produce a controlled not-found/validation response, not crash before rendering.
Current missing-detail dead render is G11. Invalid snippet `type` is proposed 400
handling (G08); actual code can fail when comparing a line count to a missing threshold.
The model intentionally represents that stronger contract and lists the difference.

**H03 (baseline).** OAuth return-to is intended to preserve an internal app destination.
Current controller stores any binary input and later relies on Phoenix's internal
redirect validation. The model abstracts callback/token lifecycle rather than URL
parsing; validate the real framework behavior with controller tests. No external
user-selected return redirect is approved by this spec.

**H04 (baseline).** Markdown interception is an exact route-pattern rule, not general
content negotiation for all HTML pages. Successful Markdown bodies receive correct
content type, nosniff and a canonical Link. Unknown `.md` patterns fall through normal
routing rather than accidentally exposing protected pages. Utility/private pages have
no default homepage canonical. Health behavior is availability reporting, not readiness
of GitHub, screenshot generation, object storage or other integrations.

OAuth endpoint details, dev utilities, static serving and error templates are documented
and linked to source tests in coverage; they are not all executable branches of the
HTTP model. The model's `signedIn`, `owner`, `basicAuth` and `exists` booleans are inputs
from the identity/domain/platform boundaries, not independently trusted client fields.
