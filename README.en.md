[简体中文](README.md) · [English](README.en.md)

![Sol single controller routes bounded work to Luna Max or Terra High and receives FILES, DIFF, and TEST evidence](docs/assets/readme/hero-en.svg)

# Sol Luna

**One Sol controller. Tiered Luna Max and Terra High execution. Delivery only after real files and evidence pass review.**

`codex-sol-luna` is a small, general-purpose Codex orchestration Skill. Simple work
stays with the current Codex; complex work is understood, planned, assigned, and reviewed
by Sol, then sent to the appropriate bounded execution tier.

| Ordinary clear task | Mixed project | Complex direct allocation | Composite center |
| --- | --- | --- | --- |
| **72%–76% budget saving** | **50%–60% budget saving** | **33%–43% budget saving** | **about 56%** |

These are budget ranges recomputed from official model ratios, routing workload, and
orchestration overhead. They are not fixed outcomes and are not a guarantee for every task. Simple Direct work
uses zero delegation and claims **0%** routing saving; the new mixed route has no completed
matched A/B comparison. A lower credit budget does not mean the work is always faster:
actual results depend on total tokens, repeated context, Sol review, and rework.

The canonical repository is [yehyakin/codex-sol-luna](https://github.com/yehyakin/codex-sol-luna).
Invoke `$sol-luna` explicitly when work is complex, cross-module, or high consequence.

## v0.3.0 release status

| Verification surface | Result |
| --- | --- |
| Local repository | Skill Creator **PASS**; **106/106** tests PASS |
| Hosted CI | POSIX **PASS**; Windows Server 2022 / `windows-latest` × Windows PowerShell 5.1 / PowerShell 7 **PASS** |
| Orchestration mode | **Compatibility verified**; Native Nested, fresh-CLI child model/effort identity, and physical Windows 11 remain unproven |

Evidence is bound to report commit `6895f06`: [POSIX CI](https://github.com/yehyakin/codex-sol-luna/actions/runs/30858707335) · [Windows CI](https://github.com/yehyakin/codex-sol-luna/actions/runs/30858707364) · [full implementation report](ORCHESTRATE_SOL_LUNA_V2_IMPLEMENTATION_REPORT.md)

![Control Orbit shows Direct, Sol-only, Sol → Luna, and Sol → Terra routes with PASS, FIX, and BLOCKED evidence returning to Sol](docs/assets/readme/control-plane-en.svg)

## 60-second quickstart

From a [codex-sol-luna](https://github.com/yehyakin/codex-sol-luna) checkout, validate
before installing:

```sh
bash scripts/validate.sh
bash scripts/install.sh
```

Describe the goal, `done_when`, file ownership, and verification commands to Codex, then
invoke `$sol-luna`. Small, independent, or explanation-only work stays Direct; the complete
platform commands and uninstall/rollback path are in [Platforms and lifecycle](#platforms-and-lifecycle).

## One controller, one execution workshop

Sol is the only controller: it owns goal interpretation, completion criteria, stage planning,
file ownership, routing, and final review. Luna Max handles clear, low-ambiguity, falsifiable
tasks with a small context; it may edit only its assigned scope and must not create subagents.
Terra High handles cross-module work, long context, ambiguous debugging, shared interfaces, or
high-risk implementation; it also stays inside an exact `write_scope` and must not create
subagents. Sol, Luna, and Terra are not a fixed three-agent team: runtime selection follows
the task and live capacity.

```text
User goal → Sol single controller plans and routes
          → Luna Max (low ambiguity) or Terra High (cross-module/high risk) executes bounded work
          → Sol reviews real files, diff, and evidence → deliver or block
```

| Role | Model / effort | Responsibility | Boundary |
| --- | --- | --- | --- |
| Sol | `gpt-5.6-sol` / `high` | controller, planner, router, final reviewer | orchestration and final decision only |
| Luna Max | `gpt-5.6-luna` / `max` | implementation and self-check for clear work | assigned files only; no subagents |
| Terra High | `gpt-5.6-terra` / `high` | cross-module, long-context, ambiguous-debugging, shared-interface, high-risk implementation | assigned files only; no subagents |

## Choose the route

The Skill does not delegate everything. First decide whether planning, execution, and review
are worth their coordination cost:

| Route | Use it for | Delegation and result |
| --- | --- | --- |
| **Direct** | Small, independent, clearly specified work | Zero delegation, **0%** routing saving, current Codex completes it |
| **Sol-only** | Clarification, planning, or review without file changes | Sol plans/reviews and stops before the execution workshop |
| **Sol → Luna** | Low-ambiguity, falsifiable work with a small context and real changes | Luna works within a unique owner scope and returns evidence to Sol |
| **Sol → Terra** | Cross-module, long-context, ambiguous debugging, shared interfaces, or high-risk implementation | Terra works within an exact owner scope and returns evidence to Sol |

Parallelism is allowed only for disjoint owner scopes; one file has one owner for the entire run.
Dependencies, shared interfaces, and uncertain boundaries wait or stay with one executor. Worker
count follows live capacity, not a fixed public team size.

## Workflow

Every delegated task follows an auditable loop:

1. **Plan.** Sol records `goal`, `done_when`, dependencies, exact `write_scope`, exclusions, and verification.
2. **Execute.** Luna or Terra receives `Task ID`, `Task`, `Context`, `Write scope`, `Do not touch`,
   `Expected result`, and `Verification`, and edits only that scope.
3. **Self-check.** The executor runs the requested checks and returns exact changed paths, diff, tests, and build evidence.
4. **Review.** Sol inspects real files and fresh evidence and decides `PASS`, one focused `FIX`, or `BLOCKED`.

Only when Luna's first failure happens before Luna writes any owned file may Sol escalate the same
task and unchanged scope to Terra once; Luna must not be retried indefinitely. If Luna has written
any owned file before failing, Luna retains all ownership; only the original Luna owner may receive
one focused fix, otherwise return `BLOCKED`. Terra's write state is never the escalation gate. Sol
reviews the re-routed result before delivery.

## Reliability comes from boundaries

Reliability comes from provable identity, ownership, evidence freshness, and bounded correction,
not from a single configuration label.

### Runtime identity and fail-closed behavior

| Agent | Model | Reasoning effort | Effective sandbox |
| --- | --- | --- | --- |
| `sol-controller` | `gpt-5.6-sol` | `high` | `read-only` |
| `luna-max-worker` | `gpt-5.6-luna` | `max` | `workspace-write`, constrained by parent boundary |
| `terra-high-worker` | `gpt-5.6-terra` | `high` | `workspace-write`, constrained by parent boundary |

Startup must prove the selected custom agent, exact model, reasoning effort, and effective
permission boundary. If any identity or permission cannot be proved, runtime **fails closed**
instead of silently substituting a similar model, role, effort, or sandbox. Luna Max and Terra
High must not spawn or create subagents, widen their write scope, rewrite Sol's plan, approve
the overall task, or present a partial result as delivery.

### Stages, ownership, evidence, and correction

A worker delivery is not final approval; completion requires Sol to review the real diff. Evidence
must bind to the final candidate through commit+diff identity or an exact changed-file snapshot.
If the candidate changes after verification, prior evidence is stale and affected checks rerun.
A transport/spawn `completed` event only proves delivery lifecycle; it cannot replace a structured
result or Sol review.

Sol may send at most one focused correction to the original owner and scope. A second failure,
missing dependency, or expanded scope is `BLOCKED`. A correction packet includes `Failure class`
and `Delta`; an identical packet without new evidence must not relaunch. Long tasks may create a
resume packet with only `goal`, `completed`, `in_flight`, `artifact_location`, and `next_action`;
short tasks and Direct work do not create one.

The machine-readable result packet is:

```text
Task ID: <stable task id>
Status: PASS | BLOCKED
Summary: <what happened>
Changed: <exact files, or None>
Verification: <commands, exit status, and concise output>
Evidence: <diff, test, build, log, or artifact location bound to the final candidate>
Failure class: runtime | model_identity | permission | dependency | scope | verification | conflict | none
Blocker: <None or the concrete blocker>
```

## Cost model and evidence boundary

This model separates API token dollars from the capacity represented by subscription credits. Official
sources are the [OpenAI model comparison](https://developers.openai.com/api/docs/models/compare) and the
official [Codex rate card](https://help.openai.com/en/articles/20001106-codex-rate-card). This snapshot is dated
**2026-08-03**; recheck both sources before publication.

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

Relative to Sol, the current ratios are Sol `1.0x`, Terra `0.4x`, and Luna `0.04x`. A
simple, reproducible blended formula is:

```text
route_cost = sol_share * 1.0 + terra_share * 0.4 + luna_share * 0.04 + orchestration_overhead
saving = 1 - route_cost
```

The `*_share` terms are token-based route shares (the three shares sum to 1 on every row), and
`orchestration_overhead` is the extra relative cost of Sol planning, review, coordination, and
necessary rework. Substitute the assumptions below to recompute each range independently; this
is not a time guarantee.

| Scenario | Reproducible assumptions (shares sum to 1) | route_cost → saving |
| --- | --- | --- |
| Ordinary clear task | `sol=.10, terra=.20, luna=.70, overhead=.03-.07` | `.208+(.03-.07)=.238-.278` → **72.2%-76.2%** |
| Mixed project | `sol=.20, terra=.40, luna=.40, overhead=.02-.12` | `.376+(.02-.12)=.396-.496` → **50.4%-60.4%** |
| Complex direct allocation | `sol=.25, terra=.60, luna=.15, overhead=.07-.17` | `.496+(.07-.17)=.566-.666` → **33.4%-43.4%** |

| Scenario | Current public budget range |
| --- | ---: |
| Ordinary clear task | 72%–76% |
| Mixed project | 50%–60% |
| Complex direct allocation | 33%–43% |
| Composite center | about 56% |

These are planning ranges, not a completed matched A/B experiment, and not a guarantee for every task;
the new mixed route must not be described as completed A/B evidence. Credit savings do not mean the work is always faster:
actual outcomes depend on token volume, repeated context, Sol review, parallel waiting, and rework.
API users see dollar amounts; subscription users mainly receive available capacity or credits.
API dollar savings and subscription capacity are different claims.

Public evidence labels remain `measured` (routing or verification records), `scenario_model_projection`
(budget ranges recomputed from official rates and scenario shares), and `unavailable` (not exposed in the source record). This page
does not present a new matched A/B measurement or a sample-validated cost; measured routing records and cost projections stay separate.

## Platforms and lifecycle

| Target | Shell | Status boundary |
| --- | --- | --- |
| macOS | POSIX shell | Supported by the `bash` lifecycle scripts |
| Linux | POSIX shell | Supported by the `bash` lifecycle scripts |
| Windows 11 | Windows PowerShell 5.1 and PowerShell 7.x | Supported target; native Windows 11 evidence is a separate release gate |
| Windows Server 2022 | Windows PowerShell 5.1 and PowerShell 7.x | Supported target; GitHub-hosted CI is Server evidence only |

GitHub Actions uses `windows-latest` and pinned `windows-2022` in the Windows matrix. Those
hosted runners provide Windows Server evidence and must not be described as native Windows 11 evidence.

### macOS and Linux

```sh
bash scripts/validate.sh
bash scripts/install.sh
bash scripts/uninstall.sh
bash scripts/uninstall.sh --restore-latest
```

For an isolated test home, set `ORCHESTRATE_HOME` to a unique temporary directory. The installer
validates source files before the first mutation, backs up exact targets, installs atomically, and
leaves unrelated agents and `~/.codex/config.toml` alone.

### Windows 11 and Windows Server 2022

The Windows lifecycle uses native PowerShell and remains compatible with PowerShell 5.1 and 7.x.
Windows PowerShell 5.1 uses `powershell.exe`; PowerShell 7 uses `pwsh`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/validate.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/uninstall.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/uninstall.ps1 -RestoreLatest
pwsh -NoProfile -File scripts/validate.ps1
pwsh -NoProfile -File scripts/install.ps1
pwsh -NoProfile -File scripts/uninstall.ps1
pwsh -NoProfile -File scripts/uninstall.ps1 -RestoreLatest
```

Set `$env:ORCHESTRATE_HOME` to a unique temporary home for isolated Windows lifecycle tests.
Windows Server CI proves Server behavior only; until a real Windows 11 run is recorded, this
README does not claim native Windows 11 evidence. The lifecycle preserves `~/.codex/config.toml`
and unrelated agents, removes only owned targets whose recorded `SHA256` still matches, and
`-RestoreLatest` / `--restore-latest` restores the latest valid backup after owned installation
removal. The release-time runtime surface and evidence status are documented in
[`docs/release/runtime-surface-matrix.md`](docs/release/runtime-surface-matrix.md).

## Real-project routing samples

These are anonymous local routing samples showing Direct, Sol-only, and bounded-worker paths;
the local project samples are routing context rather than a cost claim, and they are not a cost A/B benchmark for the new mixed route. We used only minimum read-only probes
to fill material gaps and did not modify any business project.

| Anonymous category | Route | Luna / Terra | Verification | Sol review | Elapsed |
| --- | --- | --- | --- | --- | ---: |
| Codebase | `sol_then_luna` (routing sample) | unavailable | evidence present | `BLOCKED` | 2340 s |
| Documentation | `sol_then_luna` (routing sample) | unavailable | evidence present | `PASS` | 379 s |
| Infrastructure | `direct` (routing sample) | 0 | evidence present | not applicable | 859 s |

These routing samples do not prove that the new Terra mixed path has completed A/B or turn a
credit range into a time or production guarantee. See
[`tests/real-project-benchmark.md`](tests/real-project-benchmark.md) for the complete method,
anonymous results, and limitations.

## Repository and development

### Repository layout

```text
.agents/skills/sol-luna/       public Skill and operating references
.codex/agents/                 exact Sol, Luna, and Terra custom-agent definitions
  sol-controller.toml
  luna-max-worker.toml
  terra-high-worker.toml
scripts/                       macOS/Linux lifecycle and validation scripts
tests/                         contract, forward-case, and lifecycle tests
docs/assets/readme/            repository-owned localized Control Orbit hero and control-plane SVGs
README.md                      canonical Simplified Chinese guide
README.en.md                   complete English peer
```

The public Skill is [`$sol-luna`](.agents/skills/sol-luna/SKILL.md). Exact agent definitions are
[`sol-controller.toml`](.codex/agents/sol-controller.toml), [`luna-max-worker.toml`](.codex/agents/luna-max-worker.toml),
and [`terra-high-worker.toml`](.codex/agents/terra-high-worker.toml). Global Skill and agent
directories are installed copies; GitHub is the source of truth.

### Testing

Use Python 3.11 or newer for the README, routing contract, and benchmark:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest tests.test_readme -v
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest tests.test_hybrid_routing.ReadmeCostContractTests -v
python -m unittest tests/test_contract.py
python -m unittest tests/test_benchmark.py
```

The documentation contract checks bilingual language switches and parity, canonical links, local
image targets, accessible SVG metadata, section order, current price rows, the blended formula,
budget ranges, and evidence boundaries. The benchmark report distinguishes `measured`,
`scenario_model_projection`, and `unavailable` evidence; when PowerShell is available,
lifecycle tests also exercise isolated homes with `ORCHESTRATE_HOME` and verify that
`config.toml` and unrelated agents keep their hashes.

## Limitations

- Budget ranges guide routing and do not promise the same saving for every task or token mix.
- Delegation adds planning, context, review, and possible retry tokens; retries can erase or reverse credit savings.
- Credit savings do not mean the work is always faster; parallel waiting, repeated context, and rework change outcomes.
- GitHub-hosted Windows runners establish Windows Server behavior, not native Windows 11 behavior.
- The Skill has one Sol controller and risk-tiered Luna Max and Terra High bounded executors; it is not a fixed three-agent team or a general-purpose multi-agent framework.
- Final decisions depend on real files and fresh verification; configuration labels alone cannot prove runtime identity.

## Prior art and license

### Prior art

The design was informed by reviewed snapshots of projects exploring routing, bounded delegation,
parallel scheduling, and evidence-based review; no prose or code was copied from them:

- [orchestrate-sol-luna](https://github.com/joeke80215/orchestrate-sol-luna/tree/eba163a9d48f023aeb3638b6809f0f8fb343f472) — Apache-2.0.
- [codex-parallel-subagent-planner](https://github.com/manhua-man/codex-parallel-subagent-planner/tree/ea3d8db9081e2f4159a6c40100fc1ca8d229e7dc) — no license file in the reviewed snapshot; ideas only.
- [codex-dispatch-skill](https://github.com/yinguangyao/codex-dispatch-skill/tree/00630de4c8ad01cb51bae3a89044d55cc6433158) — no license file in the reviewed snapshot; ideas only.
- [codex-orchestrate](https://github.com/douglasmonsky/codex-orchestrate/tree/f2954a066e2607deef3963465562193a220dee70) — MIT.
- [subagent-orchestrator-skill](https://github.com/Glaicer/subagent-orchestrator-skill/tree/96eaeb16f19b789fd004b588858fb846cc674147) — MIT.

### License

This repository uses the [Apache License 2.0](LICENSE). Attribution for reviewed prior art is
recorded in [NOTICE](NOTICE).

**致谢 / Thanks**

Thank you to the [LINUX DO forum](https://linux.do/) community for its attention, feedback, and support.
