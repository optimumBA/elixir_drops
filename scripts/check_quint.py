#!/usr/bin/env python3
"""Reproducible model gate. Uses only local Quint, never a database or live service."""
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUINT = ROOT / "quint/node_modules/.bin/quint"
MODELS = {
    "app": ["hasReply", "hasNotification", "rejected"],
    "delivery": ["completedImage", "failedImage", "staleJob"],
    "discovery": ["hasPages", "hasSuggestions"],
    "sponsors": ["hasImpression", "hasClick"],
    "http": [],
    "system": ["hasContent", "hasImage"],
}
SYSTEM_TESTS = "(rejectedPublishHasNoJobTest|rejectedEditHasNoSideEffectTest|editedProjectionTest)"


def execute(args, expected_success=True):
    proc = subprocess.run([str(QUINT), *map(str, args)], cwd=ROOT, text=True, capture_output=True)
    if expected_success and proc.returncode:
        raise RuntimeError(f"Quint failed: {' '.join(map(str, args))}\n{proc.stdout}{proc.stderr}")
    return proc


def mutation_checks(work):
    mutations = [
        ("app", "and old.owner == principal(device)", "", "ownershipTest"),
        ("delivery", "val current = row.code == j.code", "val current = true", "staleCompletionTest"),
        ("sponsors", "or isHead or prefetch", "", "headPrefetchTest"),
    ]
    checked = []
    for model, original, replacement, scenario in mutations:
        source = (ROOT / f"quint/{model}.qnt").read_text()
        if original not in source:
            raise RuntimeError(f"Mutation site missing: {model}: {original}")
        altered = work / f"{model}.qnt"
        altered.write_text(source.replace(original, replacement, 1))
        execute(["typecheck", altered])
        result = work / f"{model}-mutation.json"
        execute(["test", altered, "--backend=typescript", "--max-samples=1", f"--match={scenario}", f"--out={result}"], False)
        data = json.loads(result.read_text())
        if scenario not in data.get("failed", []):
            raise RuntimeError(f"Mutation was not detected by {scenario}: {data.get('stage')}, {data.get('failed')}")
        checked.append({"model": model, "scenario": scenario, "detected": True})
    return checked


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=500)
    parser.add_argument("--steps", type=int, default=300)
    parser.add_argument("--seeds", type=int, nargs="+", default=[1009, 1019, 1029])
    parser.add_argument("--receipt", type=Path, default=ROOT / "tmp/quint/latest.json")
    parser.add_argument("--model", choices=MODELS, action="append")
    parser.add_argument("--skip-mutations", action="store_true")
    args = parser.parse_args()
    if args.samples < 1 or args.steps < 1:
        parser.error("samples and steps must be positive")
    if not QUINT.exists():
        raise SystemExit("Install the pinned tool first: npm ci --prefix quint --ignore-scripts")
    models = args.model or list(MODELS)
    receipt = {"at": datetime.now(timezone.utc).isoformat(), "quint": execute(["--version"]).stdout.strip(),
               "backend": "typescript", "samples_per_seed": args.samples, "max_steps": args.steps,
               "seeds": args.seeds, "models": [], "mutation_checks": [],
               "scope": "Model type/effect checks, scenario tests and random invariant simulation; no implementation conformance or exhaustive proof."}
    temp_root = ROOT / "tmp/quint"
    temp_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=temp_root) as directory:
        work = Path(directory)
        for model in models:
            path = ROOT / f"quint/{model}.qnt"
            print(f"Checking {model}...", flush=True)
            execute(["typecheck", path])
            output = work / f"{model}-tests.json"
            tests = ["test", path, "--backend=typescript", "--max-samples=1", f"--out={output}"]
            if model == "system":
                tests.append(f"--match={SYSTEM_TESTS}")
            execute(tests)
            test_result = json.loads(output.read_text())
            if test_result.get("failed") or not test_result.get("passed"):
                raise RuntimeError(f"No successful tests for {model}")
            counts = {witness: 0 for witness in MODELS[model]}
            for seed in args.seeds:
                simulation = ["run", path, "--backend=typescript", "--invariant=inv", f"--max-samples={args.samples}",
                              f"--max-steps={args.steps}", f"--seed={seed}", "--verbosity=1"]
                simulation.extend(f"--witnesses={witness}" for witness in MODELS[model])
                proc = execute(simulation)
                for witness in counts:
                    match = re.search(rf"{re.escape(witness)} was witnessed in (\d+) trace", proc.stdout)
                    if not match:
                        raise RuntimeError(f"Missing witness output for {model}/{witness}")
                    counts[witness] += int(match.group(1))
            if any(count == 0 for count in counts.values()):
                raise RuntimeError(f"Unreached model behavior; increase samples or inspect generator: {model}: {counts}")
            receipt["models"].append({"model": model, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                                      "passed_tests": test_result["passed"], "witness_trace_counts": counts,
                                      "simulation_traces": args.samples * len(args.seeds), "invariant": "inv", "result": "passed"})
            print(f"  {len(test_result['passed'])} scenarios; {args.samples * len(args.seeds)} traces passed", flush=True)
        if not args.skip_mutations and not args.model:
            receipt["mutation_checks"] = mutation_checks(work)
            print("  All 3 deliberate faults detected", flush=True)
    receipt["source_revision"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    receipt["inputs_sha256"] = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                               for path in [ROOT / "scripts/check_quint.py", ROOT / "quint/package.json", ROOT / "quint/package-lock.json"]}
    args.receipt.parent.mkdir(parents=True, exist_ok=True)
    args.receipt.write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"Receipt: {args.receipt}", flush=True)


if __name__ == "__main__":
    main()
