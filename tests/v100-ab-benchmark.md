# v1.0 matched A/B benchmark protocol

This protocol compares the published v0.4.1 baseline with the evidence-first
candidate. It contains no performance result and declares no winner.

## Integrity rules

- Use the same user prompt, base commit, tools, permission boundary, time limit,
  model settings, and verification commands for both arms.
- Export each cell into a fresh isolated checkout without future Git objects or
  remotes that reveal the target patch.
- Keep the grader unavailable to the agent until the run ends. Record hashes for
  the prompt, grader, manifest, base commit, and final candidate.
- Run each case at least three times and use the counterbalanced schedule emitted
  by `benchmark_ab.py`.
- Record unavailable token or cost telemetry as unavailable in the capture
  adapter; never invent or convert accounting units. A result file submitted to
  this harness must contain complete comparable cells.
- Calibrate each hidden grader before paid runs: the known-bad base must fail and
  a reference-good candidate must pass.

## Cases

The manifest covers Direct routing, parallel disjoint work, missing requirement
evidence, a wrong-scope verifier, a high-risk selective challenge, interruption
resume, dirty-worktree preservation, and timeout ownership.

## Metrics

Quality and integrity:

- held-out pass;
- integrity pass;
- false PASS rate.

Efficiency:

- input and output tokens;
- elapsed seconds;
- cost value and its original unit;
- subagent count;
- retry count.

Resource savings count only when the cell passes both held-out and integrity
checks. Descriptive output is not a release claim until the complete run bundle
is independently auditable.

## Commands

```sh
python3 scripts/benchmark_ab.py validate tests/fixtures/v100-ab-benchmark.json
python3 scripts/benchmark_ab.py schedule tests/fixtures/v100-ab-benchmark.json --output schedule.json
python3 scripts/benchmark_ab.py summarize tests/fixtures/v100-ab-benchmark.json results.json --output summary.json
```

The tool does not launch Codex or any model. A separate authorized runner must
execute the frozen cells and capture measured results.
