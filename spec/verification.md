# Verify and maintain the specification

Owner: [scripts/check_quint.py](../scripts/check_quint.py). Start at the repository
root. Inputs are the six `.qnt` modules, pinned npm lockfile, relevant product Intent
and this contract. Tools are Node/npm, Python 3 and the locally installed Quint CLI;
no PostgreSQL, Java, production credentials or application server is required for
the model gate.

## Install and run

1. Read [scope/authority](README.md), relevant domain pages and [known differences](implementation-gaps.md).
2. Install the locked verification tool: `npm ci --prefix quint --ignore-scripts`.
3. Run `make spec`, or `python3 scripts/check_quint.py`.
4. Inspect `tmp/quint/latest.json`. The gate type/effect-checks every model, runs its
   deterministic scenarios and checks `inv` over 500 random traces per seed, for
   seeds 1009, 1019 and 1029, up to 300 transitions per trace. It requires every
   listed behavioral witness to be reached at least once across those seeds.
5. Confirm the three deliberate faults are detected: cross-author editing, publishing
   an older screenshot and counting HEAD/prefetch clicks. Mutated copies live only
   in a temporary local directory and never replace the maintained model.
6. For a maintained evidence refresh, run
   `python3 scripts/check_quint.py --receipt spec/validation.json`.
   The receipt records tool/backend, source hashes, scenarios, bounds, seeds,
   witness counts and the inspected source revision. Keep it synchronized after
   changing models, tool lockfile or the runner; do not edit it to fabricate a pass.

The npm package pins Quint 0.33.0; a pinned `adm-zip` 0.6.1 override removes known
advisories in the tool dependency tree. This does not change the app's dependencies.
Use the TypeScript simulator explicitly so ordinary checks do not automatically
install a native simulator or model-checking runtime.

For focused iteration, use
`python3 scripts/check_quint.py --model delivery --samples 200 --steps 300 --seeds 1009`.
A focused run does not replace the full completion gate. System scenario names are
explicitly selected in the runner to avoid counting imported component tests twice;
update that selection when adding system scenarios.

## Failure and resume

A parse/type/effect error is a model error; repair it before interpreting simulations.
An invariant violation is a contract/design counterexample: reproduce it with the
reported seed and retain the trace. A zero witness count means important behavior was
not explored; improve the generator or use larger bounds and rerun. It is not a pass.
A deliberate fault that escapes its scenario means the oracle needs repair. The gate
stops on these failures and writes a successful receipt only after all checks pass.
A prior receipt is evidence only for its matching hashes/bounds; check its date/hashes
before reusing it. Interrupted runs are repeatable; rerun the same command.

To inspect/export a counterexample or generate candidate replay inputs:

```sh
quint/node_modules/.bin/quint run quint/system.qnt \
  --backend=typescript --invariant=inv --seed=1009 \
  --max-samples=100 --max-steps=300 --mbt \
  --n-traces=10 --out-itf='tmp/quint/system_{seq}.itf.json'
```

ITF generation does not test the Elixir application. Some model actions are ghost
state/projections; any replay driver must map meaningful admissions and observations
explicitly. Follow [Quint's model-based testing guide](https://quint.sh/docs/model-based-testing)
and its [CLI reference](https://quint.sh/docs/quint). Exhaustive/symbolic verification
would be a separate command/runtime and a separate recorded claim; none was run here.
No Java runtime was available on this host during this task.

## Intent workflow

1. Load the relevant contract pages, model definitions, implementation and tests.
   Root [PROJECT_CONTEXT.md](../PROJECT_CONTEXT.md) points to the contract; loading
   a filename alone does not cause a harness to read it.
2. Identify the Intent's authorized behavior change and unchanged rules. An
   implementation-preserving refactor does not require speculative spec edits.
3. Update the canonical contract/model and affected implementation/tests together.
   Preserve rule IDs where possible. Record newly accepted decisions with provenance;
   keep proposals and discovered differences explicitly labeled.
4. Run this model gate and the implementation checks appropriate to the change.
   The existing `make ci` remains the application's gate; feature/browser tests are
   separate and need the maintained `FEATURE_TESTS=true` path. Neither substitutes
   for the other, and existing app tests are not a Quint conformance adapter.
5. Update coverage, differences, indexes and the checked receipt. Preserve executable
   sources and generated evidence together. Review the diff for unintended weakening
   of permissions, validation, isolation or failure semantics.

Completion means all declared models parse/typecheck, all selected scenarios pass,
all declared invariants pass the recorded bounded simulations, all listed witnesses
are observed, deliberate faults are caught, links are valid and the receipt matches
the saved sources. Implementation conformance, deployment and an exhaustive correctness
proof remain separate deliverables requiring their own evidence.
