# Sol Luna v0.3.0 Implementation Report

Date: 2026-08-04

Repository: https://github.com/yehyakin/codex-sol-luna

Branch context: `codex/terra-tiered-routing`

Release candidate commits: `fcd704b` (tiered routing) and `e1aa306` (native
Windows lifecycle correction)

## 1. Scope and status

This report records the completed v0.3.0 release candidate for the Sol single-controller model
with Luna Max and Terra High execution tiers. The routing contract, lifecycle scripts, bilingual
README, local artwork, forward fixtures, installation state migration, and platform tests are
integrated and pushed to the release branch. Repository checks, the macOS installation, and hosted
Windows CI are verified below. Production behavior and elapsed-time savings are not inferred from
those checks.

## 2. Final public architecture

Sol is the only controller:

```text
User goal
  -> Sol controls, plans, routes, assigns ownership, and reviews
     -> Direct, Sol-only, Sol -> Luna, or Sol -> Terra
        -> one bounded executor edits its exact scope and returns evidence
  -> Sol inspects real files, diff, tests, and evidence
  -> PASS, one focused FIX, or BLOCKED
```

Luna Max is the bounded tier for clear, low-ambiguity, falsifiable tasks with a small context.
Terra High is the bounded tier for cross-module work, long context, ambiguous debugging, shared
interfaces, and high-risk implementation. Terra is not a second controller. Sol remains the only
planner, router, and final reviewer, and the package is not a fixed three-agent team.
The regular Sol -> Terra route is **bounded complex execution**; “escalation” refers only to the
exception in which Luna first fails before writing any owned file.

Parallel execution is permitted only for disjoint ownership. One file has one owner for the entire
run. Dependencies, shared interfaces, and uncertain boundaries wait or stay with one executor.
Worker count follows live capacity rather than a public fixed maximum.

## 3. Routing behavior

| Route | Selection boundary | Result |
| --- | --- | --- |
| Direct | Small, independent, clearly specified work | Current Codex completes it; zero delegation |
| Sol-only | Analysis, clarification, planning, or review without file changes | Sol stops before an executor |
| Sol -> Luna | Low ambiguity, falsifiable, small-context work with a precise scope | Luna self-checks and returns evidence |
| Sol -> Terra | Cross-module, long-context, ambiguous debugging, shared interfaces, or high-risk implementation | Terra self-checks and returns evidence |

Only when Luna's first failure happens before Luna writes any owned file may the same task and
unchanged scope be escalated once to Terra. If Luna has written any owned file before failing, Luna
retains all ownership; only the original Luna owner may receive one focused fix, otherwise the task
is `BLOCKED`. Terra's write state is never the escalation gate. This is a single bounded upgrade,
not an infinite Luna retry loop, and Sol reviews any re-routed result before delivery.

## 4. Runtime identity and permission boundary

| Agent | Model | Reasoning | Sandbox | Public role |
| --- | --- | --- | --- | --- |
| `sol-controller` | `gpt-5.6-sol` | `high` | `read-only` | Only controller, planner, router, and final reviewer |
| `luna-max-worker` | `gpt-5.6-luna` | `max` | `workspace-write` | Bounded low-ambiguity executor; no subagents |
| `terra-high-worker` | `gpt-5.6-terra` | `high` | `workspace-write` | Bounded cross-module/high-risk executor; no subagents |

The parent permission boundary remains authoritative. Each executor may modify only the exact
assigned `write_scope`, may not create or spawn subagents, and may not approve the overall task.
Runtime dispatch must prove the selected custom agent, exact model, reasoning effort, and effective
permission. If that identity cannot be proved, dispatch fails closed instead of silently
substituting a different model or sandbox.

## 5. Evidence and correction contract

Each packet carries `Task ID`, `Task`, `Context`, `Write scope`, `Do not touch`,
`Expected result`, and `Verification`. An executor returns exact changed paths, verification
commands and results, and evidence bound to the final candidate by commit+diff identity or an exact
changed-file snapshot.

A candidate change after verification invalidates the old evidence and requires affected checks to
run again. Only a Luna failure before any Luna-owned file is written permits one same-task,
same-scope upgrade to Terra. Once Luna has written an owned file, Luna remains the sole owner for
that scope: Sol may issue at most one focused correction to Luna, and a second failure, missing
dependency, or scope expansion is `BLOCKED`. Terra's write state is never the handoff gate. Long
tasks may use a resume packet; short tasks and Direct work do not create one.

## 6. Current cost and credit accounting

The public tables use the current standard short-context rates supplied for this release and
verified on 2026-08-03 against the [OpenAI model comparison](https://developers.openai.com/api/docs/models/compare)
and the [official Codex rate card](https://help.openai.com/en/articles/20001106-codex-rate-card):

### API price per 1M tokens

| Model | Input | Cached input | Output |
| --- | ---: | ---: | ---: |
| GPT-5.6 Sol | $5.00 | $0.50 | $30.00 |
| GPT-5.6 Terra | $2.00 | $0.20 | $12.00 |
| GPT-5.6 Luna | $0.20 | $0.02 | $1.20 |

### Codex credits per 1M tokens

| Model | Input | Cached input | Output |
| --- | ---: | ---: | ---: |
| GPT-5.6 Sol | 125 | 12.5 | 750 |
| GPT-5.6 Terra | 50 | 5 | 300 |
| GPT-5.6 Luna | 5 | 0.5 | 30 |

Sol is the relative baseline `1.0`; Terra is `0.4`; Luna is `0.04`. A simple blended
budget can be recomputed as:

```text
route_cost = sol_share * 1.0 + terra_share * 0.4 + luna_share * 0.04 + orchestration_overhead
saving = 1 - route_cost
```

The shares are token-based, and the overhead is an extra relative cost for Sol planning, review,
coordination, and necessary rework. Each route's three shares sum to 1; the following assumptions
make the public ranges independently reproducible:

| Scenario | Reproducible shares and overhead | route_cost -> saving |
| --- | --- | --- |
| Ordinary clear task | `sol=.10, terra=.20, luna=.70, overhead=.03-.07` | `.208+(.03-.07)=.238-.278` -> **72.2%-76.2%** |
| Mixed project | `sol=.20, terra=.40, luna=.40, overhead=.02-.12` | `.376+(.02-.12)=.396-.496` -> **50.4%-60.4%** |
| Complex direct allocation | `sol=.25, terra=.60, luna=.15, overhead=.07-.17` | `.496+(.07-.17)=.566-.666` -> **33.4%-43.4%** |

For parity with the benchmark vocabulary, the relative line is `Sol = **1**`, `Terra High = **0.4**`,
and `Luna Max = **0.04**`. Evidence classes remain `measured`, `scenario_model_projection`, and
`unavailable`. The published range tokens are `72%-76%`, `50%-60%`, `33%-43%`, and `56%`.

The current public budget ranges are:

- ordinary clear tasks: 72%–76%;
- mixed projects: 50%–60%;
- complex direct allocation: 33%–43%;
- composite center: about 56%.

These ranges are recomputed from official ratios and routing/orchestration workload. They are not
matched A/B results for the new mixed route. Credit savings do not imply that execution is always
faster; token volume, repeated context, parallel waiting, review, and rework determine elapsed time.
API dollar accounting and subscription credit capacity are separate surfaces.

## 7. README and Control Orbit assets

The bilingual README remains Chinese-first in `README.md` with an English peer in
`README.en.md`. Both documents present the same four routes, executor boundaries, evidence
contract, current prices, relative ratios, budget ranges, platform limits, and lifecycle references.

The four repository-local SVGs retain the existing dark Control Orbit palette and view boxes:

- `hero-zh.svg` / `hero-en.svg`: `0 0 1200 420`;
- `control-plane-zh.svg` / `control-plane-en.svg`: `0 0 1200 520`.

Each SVG has local `<title>` and `<desc>` metadata, no remote resources or embedded raster,
and matching Chinese/English geometry. The visual delta adds a Terra High bounded complex-execution
orbit/node without changing the existing Sol core, Luna round trips, PASS/FIX/BLOCKED outcomes,
or ownership callout.

## 8. Installation and repository layout

The public structure now names:

```text
.codex/agents/
  sol-controller.toml
  luna-max-worker.toml
  terra-high-worker.toml
```

The stable source was installed on the iMac only after repository validation. The installer now
owns only the project Skill, its three agent files, and its own versioned state. It does not rewrite
the complete Codex configuration or other agents.

Verified installation results:

- global Skill: `~/.agents/skills/sol-luna`;
- agents: `sol-controller.toml`, `luna-max-worker.toml`, and `terra-high-worker.toml` under
  `~/.codex/agents`;
- external pre-install backup: `/tmp/sol-luna-global-backup.BN0SEL`;
- latest installer backup used for convergence verification:
  `~/.codex/sol-luna/backups/20260803T220449Z-28655`;
- the pre-existing global Skill and agent files were moved to the external quarantine rather than
  deleted;
- `bash scripts/install.sh --check`: exit 0, installation consistent;
- source/global byte comparison: Skill, Sol, Luna, and Terra all match;
- the full `~/.codex/config.toml` is byte-identical to its pre-install backup.

The installer also converges the state-only v0.1 layout transactionally, records the exact old
state in the backup manifest, and permits `--restore-latest` only when restoring cannot overwrite a
new user-owned target.

## 9. Forward tests and static verification

The final local evidence surface is:

- `PYTHONDONTWRITEBYTECODE=1 /opt/homebrew/bin/python3.13 -B -m unittest tests.test_hybrid_routing -v`;
- `PYTHONDONTWRITEBYTECODE=1 /opt/homebrew/bin/python3.13 -B -m unittest tests.test_contract -v`;
- `bash scripts/validate.sh`;
- `bash -n scripts/install.sh scripts/validate.sh scripts/uninstall.sh scripts/test.sh`;
- `git diff --check`.

Observed on the final candidate:

- Skill Creator `quick_validate.py`: **PASS**.
- Python discovery: **106 tests, 106 PASS, exit 0**.
- `bash scripts/validate.sh`: **exit 0**, structural validation PASS; PowerShell is unavailable in
  this environment and the script used deterministic structural checks.
- Shell parsing and `git diff --check`: **PASS**.
- Forward fixtures cover Direct, Sol-only, independent parallel work, shared-file conflict,
  dependency Waves, missing evidence, timeout, result conflict, omitted requirements, unavailable
  model identity, Native Nested, Compatibility, and preservation of user modifications.
- The v0.1/v0.2/v0.3 lifecycle tests cover fresh install, repeat install, read-only check, rollback,
  safe uninstall, backup restore, legacy-state convergence, modified-target refusal, and Terra
  ownership.

## 10. Native Windows verification

GitHub Actions run
[`30858280404`](https://github.com/yehyakin/codex-sol-luna/actions/runs/30858280404)
passed all four combinations for commit `e1aa306`:

- Windows Server 2022 + Windows PowerShell 5.1;
- Windows Server 2022 + PowerShell 7;
- `windows-latest` + Windows PowerShell 5.1;
- `windows-latest` + PowerShell 7.

Every job passed native parsing, `scripts/validate.ps1`, `tests/windows-lifecycle.ps1`, and the full
106-test Python discovery. The paired POSIX workflow run
[`30858280421`](https://github.com/yehyakin/codex-sol-luna/actions/runs/30858280421)
also passed. Hosted Windows Server evidence does not establish native Windows 11 behavior.

## 11. Actual agent calls and execution modes

This implementation run exercised all three configured custom agents in the Codex desktop
orchestration surface:

- Sol controlled planning, Correction Packets, conflict arbitration, and final read-only review;
- Luna Max completed bounded repository, documentation, and Windows-contract work;
- Terra High completed the cross-file legacy-state lifecycle correction and returned exact changed
  paths plus verification evidence.

Compatibility mode is therefore the verified orchestration path for this release: the main Codex
launches Sol, launches the selected worker from Sol's execution graph, and returns the real result
to Sol for review. Native Nested remains unclaimed because this release did not capture durable
evidence that Sol itself launched a worker and retrieved its result with exact runtime identity.

## 12. Parallelism, ownership, and failure behavior

Independent work streams used disjoint scopes; shared lifecycle files remained serialized. The
contract tests reject concurrent ownership of one file and hold dependency chains for Wave
execution. A worker result without minimum verification cannot become PASS.

The real Windows failure also exercised bounded recovery. The first candidate failed on all four
Windows jobs because a manifest expression was parsed as an extra positional argument. Sol refused
an additional correction inside the exhausted run. After explicit user authorization opened a new
run, the main Codex made the single deterministic fix and reran the complete platform matrix. No
worker self-approved the release.

## 13. Fresh-session discovery

A new Codex CLI session in a temporary directory discovered the installed `$sol-luna` Skill and
selected the Sol-only route. It also started the configured `sol-controller`. However, the current
CLI parent session did not receive child model/reasoning metadata that could be bound to that
launch. The test correctly returned `BLOCKED (Fail Closed)` with identity, model, and effort marked
unproven.

This proves global Skill discovery and fail-closed behavior. It does not prove custom-agent runtime
identity in the fresh CLI surface. The desktop compatibility calls above are the actual-agent
evidence for this release.

## 14. GitHub delivery and version

- repository: <https://github.com/yehyakin/codex-sol-luna>;
- release branch: `codex/terra-tiered-routing`;
- architecture commit: `fcd704b`;
- Windows correction commit: `e1aa306`;
- both POSIX and Windows workflows pass on `e1aa306`;
- public version remains v0.3.0 until the branch is reviewed and merged to `main`.

## 15. Reference projects, licenses, and design choices

The audit in `NOTICE` records exact reviewed commits and licenses. The implementation uses ideas
from the reviewed orchestration projects without copying prose or code from the two unlicensed
snapshots. This repository is Apache-2.0.

Absorbed ideas include strict controller/executor separation, Direct/Single/Parallel/Sequential
routing, Wave dependencies, read/write scopes, one-file ownership, evidence-based review, bounded
Correction Packets, and fail-closed model identity. Rejected ideas include mandatory delegation for
small tasks, permanent agent teams, dashboards/ledgers, unrestricted retries, fixed all-serial
three-role execution, and additional controller models.

## 16. Known boundaries and next recommendations

1. Sol remains the only controller and final reviewer.
2. Luna Max and Terra High are bounded executors and cannot create subagents.
3. Parallel waves require disjoint scopes and one owner per file.
4. Model identity and effective permissions fail closed when unprovable.
5. Only a Luna first failure before any Luna-owned file write allows one same-task, same-scope
   escalation to Terra; after a Luna write, ownership stays with Luna and only one focused fix is
   allowed, otherwise `BLOCKED`. Terra's write state is never the gate.
6. Budget ranges are not elapsed-time promises and do not establish completed A/B evidence.
7. Hosted Windows Server evidence is not native Windows 11 evidence.
8. Fresh CLI custom-agent identity/model/effort remains unproven because the child metadata is not
   exposed to the parent result surface.

Recommended next work is deliberately small: capture a durable runtime identity receipt when Codex
exposes one, add a matched A/B benchmark before claiming measured savings, and run the Windows
lifecycle suite on a physical Windows 11 system when available.

## 17. Sources

- [OpenAI API pricing](https://developers.openai.com/api/docs/pricing)
- [Codex rate card](https://help.openai.com/en/articles/20001106-codex-rate-card)
- [Runtime surface matrix](docs/release/runtime-surface-matrix.md)
- [Public Skill](.agents/skills/sol-luna/SKILL.md)
