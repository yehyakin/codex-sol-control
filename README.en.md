[简体中文](README.md) · [English](README.en.md)

![Sol controller assigns bounded work to Luna Max workers and receives FILES, DIFF, and TEST evidence](docs/assets/readme/hero-en.svg)

# Sol Luna

**One Sol controller. Bounded Luna Max execution. Delivery only after real files and evidence pass review.**

`codex-sol-luna` is a small, general-purpose Codex orchestration Skill. Simple
tasks stay with the current Codex; complex work is understood, planned, assigned,
and reviewed by Sol while Luna Max executes clearly bounded sub-tasks.

| Typical tested sample | Complex tested sample |
| --- | --- |
| **Typical work suitable for bounded delegation — about 59% saving** | **Complex, rework-prone work — about 65% saving** |

Both figures are validated against completed local project samples, public model rates,
and a reproducible formula; they are not a guarantee of a fixed result for every task. The 59%
scenario covers typical work suitable for bounded delegation. Simple Direct tasks use
zero delegation and claim **0%** routing savings. The 65% scenario covers complex,
rework-prone work that benefits from fail-closed behavior and bounded correction.

The canonical repository is [yehyakin/codex-sol-luna](https://github.com/yehyakin/codex-sol-luna).
Invoke `$sol-luna` explicitly when the work is complex, parallelizable, or high consequence.

![Control Orbit routes Direct, Sol-only, and Sol → Luna work into PASS, FIX, or BLOCKED evidence review](docs/assets/readme/control-plane-en.svg)

## 60-second quickstart

From a [codex-sol-luna](https://github.com/yehyakin/codex-sol-luna) checkout, validate
before installing:

```sh
bash scripts/validate.sh
bash scripts/install.sh
```

Describe the goal, `done_when`, file ownership, and verification commands to Codex,
then invoke `$sol-luna`. Small, independent, or explanation-only work stays Direct;
the complete platform commands and uninstall/rollback path are in
[Platforms and lifecycle](#platforms-and-lifecycle).

## Choose the route

The Skill does not delegate every task. First weigh the cost of planning, execution,
and review against the work itself:

| Route | Use it when | Delegation and result |
| --- | --- | --- |
| **Direct** | The task is small, independent, and clear | Zero delegation, **0%** routing savings, current Codex completes it |
| **Sol-only** | Clarification, planning, or review is needed without file edits | Sol plans and reviews, stopping before the workshop |
| **Sol → Luna** | Complex work has clear seams and real changes to make | Luna works inside an independent owner scope and returns evidence to Sol |

Good `$sol-luna` candidates have a clear `write_scope`, paths not to touch, an observable
`done_when`, and reproducible verification commands. If the goal is ambiguous, repeated
context is too expensive, or review adds little value, staying Direct is more reliable.

Sol is the single controller: it controls goal understanding, completion criteria, stage planning,
file ownership, routing, and the final review. Luna Max workers only execute bounded work, verify
their changes, and return evidence. Parallel work is allowed only across disjoint owner scopes; live
capacity determines the worker count, not a promised fixed maximum. Runtime output defaults to Simplified Chinese;
when the user explicitly requests another language, use the requested language.
Code, commands, paths, identifiers, and original evidence may retain their source form.

```text
User goal → Sol plans and routes → Luna Max executes bounded work
          → Sol reviews files, diffs, and evidence → delivery
```

| Role | Responsibility | Boundary |
| --- | --- | --- |
| Sol | Controller, planner, router, and reviewer | Orchestration and final decision only |
| Luna Max | Bounded implementation and self-verification | Assigned files only; no recursive delegation |

## Reliability comes from boundaries

Reliability comes from provable identity, ownership, evidence freshness, and bounded
correction rather than from a label in configuration.

Every delegated task follows a reviewable loop:

1. **Plan.** Sol records `goal`, `done_when`, dependencies, the exact `write_scope`, exclusions, and verification.
2. **Execute.** Luna receives a packet with `Task ID`, `Task`, `Context`, `Write scope`, `Do not touch`, `Expected result`, and `Verification`, and edits only its assigned scope.
3. **Self-check.** Luna runs the specified checks and returns exact changed paths, diff, test, and build evidence.
4. **Review.** Sol inspects the real files and fresh evidence, then chooses `PASS`, one focused `FIX`, or `BLOCKED`.

Worker completion is not final approval; delivery follows only after Sol reviews the
real diff. One file has one owner for the entire run. Disjoint scopes may run in
parallel; uncertain or overlapping scopes wait.

### Runtime identity and fail-closed behavior

| Agent | Model | Reasoning effort | Effective sandbox |
| --- | --- | --- | --- |
| `sol-controller` | `gpt-5.6-sol` | `high` | `read-only` |
| `luna-max-worker` | `gpt-5.6-luna` | `max` | `workspace-write`, bounded by the parent |

At launch, the runtime must prove the selected custom agent, exact model, reasoning
effort, and effective permission boundary. Configuration text or an agent label is
not proof. If any identity or permission cannot be proved, the runtime **fails
closed** instead of silently substituting a nearby model, role, effort, or sandbox.
Luna Max may not spawn or create subagents, widen its write scope, redesign Sol's
plan, approve the overall task, or treat a partial result as delivery.

### Stages, ownership, evidence, and correction

The workflow has four stages: Sol plans and routes; Sol assigns and Luna executes; Luna self-checks and returns evidence; Sol reviews and delivers. The result packet remains machine-
readable and falsifiable:

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

Evidence must bind to the final candidate identity using a commit+diff identity or
an exact changed-file snapshot. If the candidate changes after verification, old
evidence is stale and affected verification must be rerun; transport/spawn
`completed` only proves delivery lifecycle completion and cannot substitute for a
structured Luna `PASS`, Verification/Evidence/changed-path proof, or Sol review.

Sol may issue at most one focused correction to the original owner inside the
original scope. A second failure, missing dependency, or expanded scope is
`BLOCKED`. A Correction Packet keeps the original owner and scope and includes
`Failure class` and a `Delta`; an identical packet with no new evidence must not be
relaunched.

A Resume packet is only for a task expected to cross context compression, be
interrupted, or run for a long time. It contains only `goal`, `completed`,
`in_flight`, `artifact_location`, and `next_action`. Short and Direct tasks never
generate a Resume packet. Live capacity controls batching; the plan never assumes a
fixed Luna maximum.

### Execution continuity and planning convergence

For authorized execution, a plan is not a stop point. Stop or pause only for a
new permission request, an irreversible choice requiring confirmation, a real
blocker, or an explicit user cancellation, replacement, or redirection of the
current request; these are the only stop gates. An ordinary status question or
status inquiry does not pause authorized work, requires no new permission, and is
not a blocker. Report the state and continue the approved plan and evidence loop.

An explicit user cancellation, replacement, or redirection stops the old plan and
requires re-planning from the new request. Substantive user steering is not an
ordinary status inquiry; stop old-plan execution while Sol re-plans.

Sol uses the Host's planning timebox. Within the planning timebox, Sol must
converge to a plan, a determination, or a concrete evidence gap. The plan,
determination, or evidence gap must be produced before the planning timebox ends;
extended analysis without convergence is not progress. If a later or downstream
stage is blocked, deliver an earlier or prior stage that is evidence-complete with
its artifact and evidence. Partial delivery is allowed only when the completed
stage is evidence-complete; only unresolved downstream work remains blocked.

If transport/spawn reports `completed` without a structured result, allow exactly
one result-only follow-up to the same worker. The follow-up cannot authorize a new
write or re-execution. If it still cannot retrieve a structured result bound to the
final candidate, return `BLOCKED`; do not launch another retrieval or re-execute.

User urgency, requests to hurry, or saying "do not stop" cannot lower, relax, or
reduce the evidence or verification threshold. The evidence threshold remains
unchanged and every safety gate still applies.

## Cost projection and test method

This model separates API token prices in dollars from the capacity represented by a
subscription credit. The official sources are the [OpenAI API pricing
page](https://developers.openai.com/api/docs/pricing) and the official
[Codex/ChatGPT rate card](https://learn.chatgpt.com/docs/pricing). This snapshot is
dated **2026-08-02**; recheck both sources on release day.

### Standard short-context API prices per 1M tokens

| Model | Input | Cached input | Cache write | Output |
| --- | ---: | ---: | ---: | ---: |
| GPT-5.6 Sol | $5.00 | $0.50 | $6.25 | $30.00 |
| GPT-5.6 Luna | $0.20 | $0.02 | $0.25 | $1.20 |

### ChatGPT credits per 1M tokens

| Model | Input | Cached input | Output |
| --- | ---: | ---: | ---: |
| GPT-5.6 Sol | 125 | 12.5 | 750 |
| GPT-5.6 Luna | 5 | 0.5 | 30 |

Across these token categories, Luna costs `1/25` of Sol. Moving an otherwise
identical worker-token segment from Sol to Luna reduces that segment by **96%**;
this is a segment comparison, not a promise about an entire task.

The transparent projection is:

```text
savings = delegated_share * (1 - luna_duplication / 25) - sol_overhead
```

Here, `delegated_share` is the share of an all-Sol run that Luna performs instead,
`luna_duplication` is Luna's token volume relative to that delegated baseline, and
`sol_overhead` is additional Sol planning and review beyond the all-Sol baseline.

| Scenario | Delegated share | Luna duplication | Added Sol overhead | Sample-validated saving |
| --- | ---: | ---: | ---: | ---: |
| Conservative | 50% | 125% | 10% | about 38% |
| Typical | 70% | 115% | 8% | about 59% |
| Reliability-gated complex | condition-based | 15% avoided invalid rework | 41% after typical | about 65% |

After the typical projection, avoiding invalid rework equal to 15% of the remainder leaves
41% * 85% = 34.85%, therefore about 65% saved. This method matches the fail-closed,
verification, and bounded-correction paths observed in the local complex-task samples.

For a simple reference point, an all-Sol short-context workload with 1M input and
0.1M output costs about **$8.00** or **200 ChatGPT credits**. Under the typical
assumptions, the routed equivalent is about **$3.30** or **82.4 credits**, a
reduction of about **59%**. Direct tasks use zero delegation and claim **0%** routing
savings.

These projections use local project test samples and public rates; they are not a fixed
guarantee for every task. Poor decomposition,
repeated context, unusually large Sol reviews, low delegation, or retries can reduce,
reverse, or erase the benefit; retries can erase savings entirely. API users may see
monetary dollar savings. Subscription users primarily receive more usable capacity or
credits, unless routing also avoids buying extra credits or moving to a higher plan.
API dollar savings and subscription capacity are different claims.

## Platforms and lifecycle

| Target | Shell | Status boundary |
| --- | --- | --- |
| macOS | POSIX shell | Supported by the `bash` lifecycle scripts |
| Linux | POSIX shell | Supported by the `bash` lifecycle scripts |
| Windows 11 | Windows PowerShell 5.1 and PowerShell 7.x | Supported target; native Windows 11 evidence is a separate release gate |
| Windows Server 2022 | Windows PowerShell 5.1 and PowerShell 7.x | Supported target; GitHub-hosted CI is Server evidence only |

GitHub Actions uses `windows-latest` and pinned `windows-2022` in the Windows
matrix. Those hosted runners provide Windows Server evidence and must not be
described as native Windows 11 evidence.

### macOS and Linux

```sh
bash scripts/validate.sh
bash scripts/install.sh
bash scripts/uninstall.sh
bash scripts/uninstall.sh --restore-latest
```

For an isolated test home, set `ORCHESTRATE_HOME` to a unique temporary directory.
The installer validates source files before the first mutation, backs up exact
targets, installs atomically, and leaves unrelated agents and
`~/.codex/config.toml` alone.

### Windows 11 and Windows Server 2022

The Windows lifecycle is native PowerShell and remains compatible with PowerShell
5.1 and PowerShell 7.x. Windows PowerShell 5.1 uses `powershell.exe`; PowerShell 7
uses `pwsh`:

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

Set `$env:ORCHESTRATE_HOME` to a unique temporary home for isolated Windows
lifecycle tests. Windows Server CI proves Server behavior only; until a real
Windows 11 run is recorded, this README does not claim native Windows 11 evidence.

The lifecycle preserves `~/.codex/config.toml` and unrelated agents. An unmodified
legacy v0.1 installation may be migrated; a modified legacy target is retained
rather than silently deleted. Uninstall removes only owned targets whose recorded
`SHA256` still matches. `-RestoreLatest` / `--restore-latest` restores the latest
valid recorded backup after owned installation removal. The release-time runtime
surface and evidence status are documented in
[`docs/release/runtime-surface-matrix.md`](docs/release/runtime-surface-matrix.md).

## Real-project routing samples

These are anonymous local real-project test samples. We reused completed Sol Luna task
evidence and allowed only the minimum read-only probes needed to fill material gaps; no
business project was modified.

| Anonymous category | Route | Luna workers | Waves | Verification | Sol review | Elapsed |
| --- | --- | ---: | ---: | --- | --- | ---: |
| Codebase | `sol_then_luna` (`measured`) | `unavailable` | `unavailable` | evidence present (`measured`) | `BLOCKED` (`measured`) | 2340 s (`measured`) |
| Documentation | `sol_then_luna` (`measured`) | `unavailable` | `unavailable` | evidence present (`measured`) | `PASS` (`measured`) | 379 s (`measured`) |
| Infrastructure | `direct` (`measured`) | 0 (`measured`) | 0 (`measured`) | evidence present (`measured`) | not applicable (`measured`) | 859 s (`measured`) |

Routing, elapsed time, verification, and Sol review come from real records. The 59% and
65% figures use those local project samples, public model rates, and the formula below
under one reproducible accounting method. See
[`tests/real-project-benchmark.md`](tests/real-project-benchmark.md) for the complete
method, anonymous results, and limitations.

## Repository and development

### Repository layout

```text
.agents/skills/sol-luna/       public Skill and operating references
.codex/agents/                 exact Sol and Luna custom-agent definitions
scripts/                       macOS/Linux lifecycle and validation scripts
tests/                         contract, forward-case, and lifecycle tests
docs/assets/readme/            repository-owned localized Control Orbit hero and control-plane SVGs
README.md                      canonical Simplified Chinese guide
README.en.md                   complete English peer
```

The public Skill is [`$sol-luna`](.agents/skills/sol-luna/SKILL.md). Exact agent
definitions are [`sol-controller.toml`](.codex/agents/sol-controller.toml) and
[`luna-max-worker.toml`](.codex/agents/luna-max-worker.toml). Global Skill and
agent directories are installed copies; GitHub is the source of truth.

### Testing

Use Python 3.11 or newer for the documentation testing contract, repository URL
contract, and benchmark:

```sh
python -m unittest tests/test_readme.py
python -m unittest tests/test_contract.py
python -m unittest tests/test_benchmark.py
```

The documentation contract checks bilingual language switches and parity,
canonical links, local image targets, accessible SVG metadata, section order,
pricing rows, formula assumptions, scenario estimates, and disclaimers. The
benchmark report distinguishes `measured`, `sample_validated_projection`, and `unavailable` evidence
boundary. When PowerShell is available, lifecycle tests also exercise isolated
homes with `ORCHESTRATE_HOME` and verify that `config.toml` and unrelated agents
keep their hashes.

## Limitations

- The cost results above are validated against local project samples but do not claim every routed task produces an identical result.
- Delegation adds planning, context, review, and possible retry tokens; retries may completely erase savings.
- GitHub-hosted Windows runners establish Windows Server behavior, not native Windows 11 behavior.
- The Skill intentionally keeps two roles: Sol controls and Luna Max executes; it is not a general-purpose multi-agent team framework.
- Final decisions depend on real files and fresh verification; configuration labels alone cannot prove runtime identity.

## Prior art and license

### Prior art

The design was informed by reviewed snapshots of projects exploring routing,
bounded delegation, parallel scheduling, and evidence-based review; no prose or
code was copied from them:

- [orchestrate-sol-luna](https://github.com/joeke80215/orchestrate-sol-luna/tree/eba163a9d48f023aeb3638b6809f0f8fb343f472) — Apache-2.0.
- [codex-parallel-subagent-planner](https://github.com/manhua-man/codex-parallel-subagent-planner/tree/ea3d8db9081e2f4159a6c40100fc1ca8d229e7dc) — no license file in the reviewed snapshot; ideas only.
- [codex-dispatch-skill](https://github.com/yinguangyao/codex-dispatch-skill/tree/00630de4c8ad01cb51bae3a89044d55cc6433158) — no license file in the reviewed snapshot; ideas only.
- [codex-orchestrate](https://github.com/douglasmonsky/codex-orchestrate/tree/f2954a066e2607deef3963465562193a220dee70) — MIT.
- [subagent-orchestrator-skill](https://github.com/Glaicer/subagent-orchestrator-skill/tree/96eaeb16f19b789fd004b588858fb846cc674147) — MIT.

### License

This repository is licensed under [Apache License 2.0](LICENSE). Attribution
context for reviewed prior art is recorded in [NOTICE](NOTICE).

**致谢 / Thanks**

Thank you to the [LINUX DO forum](https://linux.do/) community for its attention,
feedback, and support.
