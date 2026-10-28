# ElixirDrops application specification

This is the behavioral contract for the existing web application. It gives future
Intents and implementations a common reference, with executable Quint models for
state and ordering rules. It is independent of the choice of server language or
database; it does not authorize a migration or add mobile applications.

Baseline: source commit `04ffe01a997e4e10c0c151c062b43c336ccae963`, inspected on
9 October 2026. The user's request was “Let's write Quint spec for the whole
ElixirDrops app”, following the [spec/Intent context discussion](thread://01a11fb2-5192-72d1-ae14-9f30626e7dc9?hostId=local).
Source code and maintained operational documents provide the behavioral evidence.
The companion iCloud Area owns editorial/commercial decisions and live services
own published content and payments; none of that private data is included here.

## Start here

1. [Domain and access rules](domain.md) — accounts, Drops, comments, notifications.
2. [Discovery and interaction](discovery.md) — timeline, search, profile, browser behavior.
3. [Delivery and derived content](delivery.md) — screenshots, caching, sitemap, rendering.
4. [HTTP contract](http.md) — routes, representations, authentication and failures.
5. [Sponsor measurement](sponsors.md) — eligibility, anonymity, redirects and reports.
6. [Coverage and abstraction map](coverage.md) — rules → models → source/tests.
7. [Implementation differences](implementation-gaps.md) — observed omissions and proposed refinements.
8. [Verification and maintenance](verification.md) — installation, checking, traces, Intent workflow.

Executable source: [quint/](../quint/README.md). Latest checked evidence:
[validation.json](validation.json). Run `make spec` from the repository root.

## Authority

Rules described as **baseline** preserve source behavior or an existing documented
product intent. A source omission does not erase an evident permission boundary
(for example, the UI only offers comment editing to its author). **Refinements**
are explicitly identified in the gaps page: they are proposed stronger contracts,
not newly accepted product decisions or a queue of authorized implementation work.
Do not make a spec pass by weakening it to match a bug. Record the difference and
shape the implementation or contract change through an authorized Intent.

The models include the intended comment access boundary and proposed deterministic
pagination, stale-image fencing, status preservation and invalid-input handling.
They therefore describe a target contract as well as current behavior. Passing the
models does **not** mean the existing Elixir implementation conforms to every rule.

## What “whole app” covers

All current product surfaces and domains have an owner here: GitHub login/logout,
remember-me, publishing/editing, public browsing, profile, threaded discussion,
notifications, search and tracking, screenshots, Markdown/HTML, SEO/archive/sitemap,
health/dev utilities, sponsor events/redirects and browser hooks. No public Drop
or account deletion, draft/approval state, votes, API, billing portal, scheduler for
social posting, moderation role or native client is invented.

Quint models state transitions and safety properties. String rendering, PostgreSQL
query interpretation, cryptography, browser layout and external services have
explicit contracts and existing test mappings rather than a false claim of formal
coverage. [Coverage](coverage.md) distinguishes these limits and the composition.

Folder map: `spec/` owns rules, coverage, known differences and verification;
`quint/` owns executable models and pinned tooling; `scripts/check_quint.py` owns
the repeatable gate. Existing `context/` pages still own implementation navigation,
and `docs/` still owns sponsor operations and SEO procedures.
