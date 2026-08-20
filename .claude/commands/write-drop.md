---
description: Suggest and write a verified ElixirDrops post
---

# Write an ElixirDrop

Suggest 5–10 non-duplicative topics, let the user select one, then write and validate the drop and its two social hooks (X and LinkedIn). Keep one clear problem and one clear solution. Prefer working code and observed output over illustrative claims.

## 0. Preflight

Work from the ElixirDrops project root. The verified baseline on 2026-08-20 is Elixir 1.20.2 / OTP 29, Phoenix 1.8, Phoenix LiveView 1.1, and Ecto SQL 3.13. Check the current environment before relying on it:

```bash
elixir --version
mix deps | grep -E 'phoenix |phoenix_live_view |ecto_sql '
```

Optional local material must never block the command. Check whether a proposed rules or recipes directory exists; if absent, proceed using this command, the repository, official HexDocs, published drops, and drafts. Do not search for or require the obsolete `~/Areas/Optimum/context/rules/subagents/*.md` or `~/Areas/Optimum/context/recipes/` paths.

If the user supplied a Plausible screenshot, use only metrics visible there: visitors, pageviews, bounce rate, time on page, and scroll depth. If none was supplied, ask once; if the user declines or it is unavailable, proceed without analytics. Never invent or relabel impressions. Treat warning/solution, performance, developer-UX, workflow, and hidden-feature angles only as historical editorial priors unless the supplied dashboard supports them.

## 1. Discover topics without duplication

This gate is mandatory. Do not present a topic until every step passes.

1. Use WebFetch on `https://elixirdrops.net/index.md` with: “Return the complete list exactly as `Title /shortid`, one entry per line; do not summarize or truncate.” The index contained about 155 entries on 2026-08-20. If the result is unexpectedly small or lacks short IDs, fetch again or report the failure; do not continue with a partial catalogue.

2. Inventory drafts and hooks:

   ```bash
   find ./drops -maxdepth 1 -type f -name '*.md' -print | sort
   ```

   Prefer a worthwhile unfinished draft before inventing a new topic. Note any `_drop.md` missing its matching `_hooks.md`, or a `_hooks.md` missing either section.

3. Build an avoidance list from every published title and every draft. Compare concepts, not just wording: aliases, failure modes, and alternative APIs count as possible overlap.

4. For each candidate, identify its nearest published and draft neighbors. Use WebFetch on `https://elixirdrops.net/d/{shortid}.md` for every plausible near-match and read the full body. Remove the candidate if its core problem and solution are already covered.

5. Present 5–10 surviving suggestions, each with:
   - **Title** — 30–57 characters
   - **Problem** — the concrete problem it solves
   - **First block** — the screenshot-worthy code concept
   - **Nearest neighbor** — closest published/draft drop and why this is materially distinct

Do not claim “zero duplication” from title matching alone. If the complete index or relevant near-match bodies cannot be fetched, say the duplication check is incomplete and stop before recommending topics.

## 2. Write the selected drop

### Title and body

- Title: 30–57 characters, action-oriented, sentence case. Count it exactly.
- Open with a direct technical instruction, warning, or immediately useful outcome. No throat-clearing or marketing language.
- Make the first code block the strongest visual: it is the social screenshot. Show the solution immediately, or a compact ❌/✅ contrast in one block. Use real context, clear names, and only enough code to reveal the technique.
- Explain why it works, then add only the edge cases or gotchas needed to use it safely.
- End with a markdown link to the most relevant official HexDocs page: `[Module.function/arity docs](https://hexdocs.pm/...)`.
- Never invent metrics, benchmark results, version behavior, warning text, or output. Include numbers only when reproduced by the validation below. Show the measured before/after values; do not derive a percentage unless the math is also verified.

Count a proposed title without its Markdown decoration:

```bash
printf %s 'Exact title text' | wc -m
```

### X hook

- Hard limit: 280 characters; target 240–250 for buffer. Count characters exactly.
- State the problem and solution directly. Use only facts present in the drop.
- No “thread,” “here’s how,” pointing-down emoji, or marketing filler.
- Put `https://elixirdrops.net/d/[id]` at the end.
- Prevent Twitter auto-linking of `Module.function` by inserting a zero-width space (ZWSP, U+200B) immediately after the dot: `File​.read!/1`, `Enum​.map/2`, `Ecto​.Query`, `Phoenix​.LiveView`. The copyable character is between the dot and the following name in those examples.

Both hooks live in one file, `./drops/NAME_hooks.md`, under `## X` and `## LinkedIn` headings. The
headings are delimiters only — never paste them. Count the X section on its own:

```bash
awk '/^## X$/{f=1;next} /^## LinkedIn$/{f=0} f' ./drops/NAME_hooks.md | tr -d '\n' | wc -m
```

### LinkedIn hook

The X hook does not work on LinkedIn. Write a separate one; do not paste one into the other.

What is different, and why:

- **Markdown is stripped.** LinkedIn renders no backticks, bold, or headings — they appear as literal characters. Write plain text. Show code as bare lines with blank lines around it, never in a fenced or backticked block.
- **No 280-character limit.** The post cap is 3,000 characters; 1,200–1,700 is a comfortable working range. Use the room to explain the mechanism, not to add filler.
- **The first line is the whole ad.** LinkedIn collapses the post behind a "…see more" fold at roughly 140 characters on mobile (the exact cut is undocumented and shifts). Make line 1 stand alone under ~140 characters and land the problem or the number. Verify with the command below.
- **Line breaks survive and matter.** Short paragraphs, one idea each, blank line between. A wall of text is not read.
- **No ZWSP.** That trick exists only because X linkifies `Module.function`. LinkedIn does not. Insert no zero-width spaces here — they are pure corruption risk in this file.
- **Hashtags on the last line.** Three or four, lowercase, e.g. `#elixir #phoenix #otp`.
- **Link on its own line** before the hashtags, same `https://elixirdrops.net/d/[id]` form.

Same factual discipline as the X hook: every claim and every number must already appear in the drop and have been reproduced during validation.

Verify both sections in one pass. The two have opposite ZWSP requirements, so the check is scoped per
section — it reports X length and ZWSP, and the LinkedIn fold, markdown, and ZWSP:

```bash
python3 - ./drops/NAME_hooks.md <<'CHECK'
import re, sys
b = open(sys.argv[1]).read()
x = b.split("## X", 1)[1].split("## LinkedIn")[0].strip()
l = b.split("## LinkedIn", 1)[1].strip()
print("X  :", len(x), "chars (<=280) | ZWSP", x.count("\u200b"), "(one per Module. in it)")
print("LI :", len(l), "chars | line1", len(l.split("\n")[0]), "(<140) | ZWSP",
      l.count("\u200b"), "(must be 0) | markdown",
      "FOUND" if re.search(r"[`*]", l) else "none")
CHECK
```

Do not flag a bare `#` in the LinkedIn section: `#=>` in pasted output and `#{...}` in interpolation
are legitimate and frequent. LinkedIn only forms a hashtag when a word character follows the `#`, so
neither becomes a link — but a stray `#` immediately before a word does.

## 3. Validate every code block

Use one scratch file per independent block. Paste the formatted, executed version back into the drop. Never present `# =>` output until it matches actual output.

### A. Standalone Elixir

Create the scratchpad inside the project root so the project `.formatter.exs` applies:

```bash
cat > .drop_check_1.exs <<'ELIXIR'
# Paste one standalone snippet here.
ELIXIR
mix format .drop_check_1.exs
mix format --check-formatted .drop_check_1.exs
elixir .drop_check_1.exs
```

Copy real output into verified `# =>` comments, rerun, and remove the scratch file when finished:

```bash
rm .drop_check_1.exs
```

### B. Code needing project dependencies

Use `mix run --no-start`; `--no-start` prevents the application supervision tree from starting when Postgres is unavailable.

```bash
cat > /tmp/check.exs <<'ELIXIR'
# Paste code using Phoenix.Component, Ecto.Schema, or another project dependency.
ELIXIR
mix run --no-start /tmp/check.exs
cp /tmp/check.exs .drop_check_deps.exs
mix format .drop_check_deps.exs
mix format --check-formatted .drop_check_deps.exs
```

Copy the formatted project-root file back into the drop, rerun it if formatting changed behavior, then clean up:

```bash
mix run --no-start .drop_check_deps.exs
rm .drop_check_deps.exs /tmp/check.exs
```

### C. Literal compile-time warnings

First format and execute the code being demonstrated using A or B. Then paste that formatted code into the heredoc and capture warnings under the project dependencies:

```bash
cat > /tmp/check.exs <<'ELIXIR'
Code.put_compiler_option(:ignore_module_conflict, true)

code = ~S"""
# Paste the modules/code that should emit the warning here.
"""

Code.compile_string(code, "demo.exs")
ELIXIR
mix run --no-start /tmp/check.exs 2>&1 | tee /tmp/check.out
```

Quote only the literal warning captured in `/tmp/check.out`. Modules created by `Code.compile_string/2` cannot be referenced later in the same script with `%Struct{}` literals; construct and call them dynamically instead:

```elixir
value = struct(Demo, %{})
apply(Demo, :run, [value])
```

For measurements, keep the measured return value genuinely alive by printing it, returning it, or otherwise consuming it. Do not bind it only to an underscore-prefixed variable: the compiler may discard the work and silently produce a zero measurement.

### D. Final verification

- Re-run every block using A, B, or C as appropriate.
- Verify every public API and behavioral claim against the relevant official HexDocs page.
- Run `mix format --check-formatted` on every project-root scratch file. Formatting a path from another working directory does not reliably apply this project’s `.formatter.exs`, including its Ecto/Phoenix imports and formatter plugins.
- If `mcp__tidewave__project_eval` is available **and** a Phoenix server is already running, it may be used as an optional extra check. Never require it or start `mix phx.server` for this command. When Tidewave is absent, the `elixir` and `mix run --no-start` paths above are the fallback and source of truth.
- Perform the duplication gate again against the finished angle, not only the initial title.

## 4. Save exactly two files

Write the files directly; do not delegate file writes to unavailable or assumed agent types:

- `./drops/NAME_drop.md` — complete drop
- `./drops/NAME_hooks.md` — both hooks, `## X` section then `## LinkedIn` section

The headings are delimiters for you, not part of either post. Each section below its heading is the
literal text to paste, ZWSP already embedded in the X one.

A drop with no matching `_hooks.md`, or a `_hooks.md` missing either section, is incomplete. When you
touch any drop, check for both files and both sections, and write whatever is missing.

Before finishing, confirm: the title is 30–57 characters; the X section is at most 280 characters and
carries a ZWSP after every `Module.` in it; the LinkedIn section has a first line under ~140
characters, contains no markdown and no ZWSP, and makes no claim absent from the drop; the first code
block is screenshot-ready; all shown output and metrics were reproduced; the HexDocs link is present;
and the final semantic duplication check passed.
