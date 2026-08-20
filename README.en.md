[简体中文](README.md) · [English](README.en.md)

![Codex PROVE plans, routes, assigns ownership, verifies, and evidence-gates complex work](docs/assets/readme/hero-en.svg)

# Codex PROVE

**Plan the work. Route the right model. Prove the result.**

`codex-prove` is a model-neutral orchestration Skill for Codex. It does not optimize for “more agents.” It keeps one auditable control protocol and treats models as replaceable configuration:

- **Controller** is the sole decision owner: understand, plan, route, assign ownership, schedule, and perform the final review.
- **Complex worker** handles cross-module, long-context, ambiguous-debugging, shared-interface, and high-consequence implementation.
- **Efficient worker** handles clear, low-ambiguity, tightly bounded, independently verifiable execution.

Simple tasks stay with the current Codex session. Explicitly invoke `$codex-prove` for work that is complex, cross-module, parallelizable, or high-consequence.

> **v1.0.0 migration:** Sol Control is now Codex PROVE. Use `$codex-prove`; `$sol-control` remains an explicit compatibility alias for v1.0 and redirects to the same PROVE protocol. The installer can transactionally migrate managed v0.1–v0.5 installs, and `--restore-latest` restores the pre-upgrade state.

Runtime output defaults to Simplified Chinese unless the user explicitly requests another language.

> **One controller, two worker profiles. Workers are leaves: they cannot create subagents or approve the overall task.**

Canonical repository: [yehyakin/codex-prove](https://github.com/yehyakin/codex-prove)

## Core routing and projected savings

The table below uses an “all work performed by Sol” baseline of `1.00×`. Model token shares total 100%. `Orchestration overhead` represents additional Sol planning, review, coordination, and necessary rework as a fraction of the all-Sol baseline.

| Scenario | Example token routing | Orchestration overhead | Projected saving |
| --- | --- | ---: | ---: |
| **Ordinary clear project** | Sol 10% · Terra 20% · Luna 70% | 3%–7% | **72.2%–76.2%** |
| **Mixed project** | Sol 20% · Terra 40% · Luna 40% | 2%–12% | **50.4%–60.4%** |
| **Complex project** | Sol 25% · Terra 60% · Luna 15% | 7%–17% | **33.4%–43.4%** |
| **Direct small task** | The current Codex completes it without delegation | 0% | **0% routing saving** |

## Why it can reduce cost

The cost strategy is straightforward:

> **Keep goal interpretation, boundary decisions, and final review with Sol; route implementation to Terra or Luna according to complexity.**

Using the official API prices and Codex token-based rate card checked on **2026-08-04**, the relative cost of the same token type is:

| Model | Relative cost | Responsibility in this project |
| --- | ---: | --- |
| **Sol** | **1.00×** | Understand, plan, assign, schedule, and review |
| **Terra High** | **0.40×** | Complex, cross-module, long-context, or high-risk execution |
| **Luna Max** | **0.04×** | Clear, low-ambiguity, high-throughput execution |

For the same token type:

- Terra costs about **40%** of Sol;
- Luna costs about **4%** of Sol;
- Luna does not replace Sol—it moves large amounts of well-specified execution away from Sol while preserving Sol's judgment and review role.

These values are `scenario_model_projection`: they are planning estimates, **not matched A/B experiments, not per-task guarantees, and not latency promises**. Repeated context, poor decomposition, parallel waiting, output volume, Fast mode, and rework can reduce or reverse the saving.

A defensible public claim is therefore:

> **Ordinary clear projects can project roughly 72%–76% savings, typical mixed projects roughly 50%–60%, and complex projects roughly 33%–43%; actual results must be recalculated from real routing and token usage.**

It is not accurate to compress every workload into a fixed “56% average saving.”

<details>
<summary><strong>View official rates, formula, and full calculation</strong></summary>

### API prices

Per 1M tokens:

| Model | Input | Cached input | Output |
| --- | ---: | ---: | ---: |
| GPT-5.6 Sol | $5.00 | $0.50 | $30.00 |
| GPT-5.6 Terra | $2.00 | $0.20 | $12.00 |
| GPT-5.6 Luna | $0.20 | $0.02 | $1.20 |

### Codex token-based credits

Per 1M tokens:

| Model | Input | Cached input | Output |
| --- | ---: | ---: | ---: |
| GPT-5.6 Sol | 125 credits | 12.5 credits | 750 credits |
| GPT-5.6 Terra | 50 credits | 5 credits | 300 credits |
| GPT-5.6 Luna | 5 credits | 0.5 credits | 30 credits |

The current relative ratios are identical across both accounting surfaces:

```text
Sol = 1.00
Terra = 0.40
Luna = 0.04
```

That allows the same relative-cost formula:

```text
route_cost =
  sol_share × 1.00
  + terra_share × 0.40
  + luna_share × 0.04
  + orchestration_overhead

saving = 1 - route_cost
```

Ordinary clear project example:

```text
route_cost
= 0.10 × 1.00
+ 0.20 × 0.40
+ 0.70 × 0.04
+ 0.03–0.07
= 0.238–0.278

saving
= 1 - 0.238–0.278
= 72.2%–76.2%
```

API users see dollar charges; ChatGPT / Codex users usually see credits or included capacity. They are different accounting units, so API dollar savings should not be described as an identical subscription-bill saving.

Official sources:

- [OpenAI model comparison](https://developers.openai.com/api/docs/models/compare)
- [OpenAI Codex rate card](https://help.openai.com/en/articles/20001106-codex-rate-card)

A small subset of Enterprise workspaces still using the legacy rate card should use the rate card that actually applies to their workspace.

</details>

## 60-second quickstart

### macOS / Linux

```sh
git clone https://github.com/yehyakin/codex-prove.git
cd codex-prove

bash scripts/validate.sh
bash scripts/install.sh
```

### Windows

Windows PowerShell 5.1:

```powershell
git clone https://github.com/yehyakin/codex-prove.git
Set-Location codex-prove

powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/validate.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1
```

PowerShell 7:

```powershell
pwsh -NoProfile -File scripts/validate.ps1
pwsh -NoProfile -File scripts/install.ps1
```

After installation, open a new Codex session and explicitly invoke:

```text
$codex-prove

Goal: Add account settings to the existing Next.js application.

Done when:
- Users can update their display name and avatar
- Existing authentication APIs remain compatible
- Required tests are added
- Lint, test, and build all pass

Do not:
- Modify the payments module
- Replace the existing UI framework
```

A one-line request also works:

```text
$codex-prove Refactor the authentication module, preserve the current API, and make sure tests and build pass.
```

You do not need to choose a worker count or model. Provide the **goal, observable completion criteria, and important constraints**; the controller creates the smallest useful execution graph.

## What it solves

| Common problem | Codex PROVE's response |
| --- | --- |
| One agent plans, implements, and verifies too much at once | The controller owns judgment and review; workers own bounded execution |
| Every task uses the highest-cost model | Execution is routed to efficient or complex capability profiles |
| Multiple executors touch shared files | **One file, one owner**; overlapping work runs sequentially |
| “Done” is reported without inspectable proof | Results must include changed paths, diff, tests, builds, or artifacts |
| A failed task is retried indefinitely | One bounded correction is allowed; otherwise it becomes `BLOCKED` |

The goal is not a noisy multi-agent team. It is a clear, auditable control plane for complex work.

## How it works

![Direct, controller-only, efficient-worker, and complex-worker paths, with evidence returning for final review](docs/assets/readme/control-plane-en.svg)

```text
User goal
   │
   ▼
Controller: understand → plan → route → assign → schedule
   │
   ├─ Direct: the current Codex handles simple work
   ├─ Controller-only: planning, analysis, or review without file changes
   ├─ Efficient worker: clear, low-ambiguity, independently verifiable execution
   └─ Complex worker: cross-module, long-context, or high-consequence execution
   │
   ▼
Real files + diff + test / build / artifact evidence
   │
   ▼
Controller: artifact-first review by REQ-ID → PASS / FIX / BLOCKED
```

### Evidence-first control

The v1.0 contract keeps one controller and does not add a second reviewer. It
retains five quality controls:

1. **Requirement-to-evidence graph.** Every `done_when` item has a stable `REQ-ID`; tasks, verification, and final evidence map back to it.
2. **Artifact-first review.** The controller reads the original requirements, real changed paths, files, complete diff, and verification artifacts before worker `PASS` claims or summaries.
3. **Verify the verifier.** Exit zero is insufficient. The check must target the final candidate, correct scope, and intended requirement; wrong-module and existence-only checks do not pass.
4. **Selective challenge.** Ordinary work has zero extra challenge calls. High-consequence, cross-module, shared-interface, conflicting-evidence, or uncovered-requirement work may receive at most one read-only challenge. It returns findings; the controller retains the verdict.
5. **Recoverable execution.** Long runs preserve owners, candidate identity, requirement coverage, and attempt counts; resume does not redispatch completed work or reset the correction budget.

### Role hierarchy

| Role | Configuration | Owns | Explicit boundary |
| --- | --- | --- | --- |
| **Controller** | `prove-controller` → `gpt-5.6-sol` / `high` / `read-only` | Goal understanding, `done_when`, routing, ownership, stages, final review | Does not perform bulk mechanical implementation |
| **Complex worker** | `prove-complex-worker` → `gpt-5.6-terra` / `high` / `workspace-write` | Cross-module work, long context, ambiguous debugging, shared-interface judgment, high-consequence implementation | Not a second controller; does not rewrite the plan or create subagents |
| **Efficient worker** | `prove-efficient-worker` → `gpt-5.6-luna` / `max` / `workspace-write` | Clear, low-ambiguity, small-context, mechanical, or high-throughput execution | Does not expand scope, create subagents, or approve the overall task |

Role names stay stable; the models after each arrow are the v1.0 default profile. Future model generations update TOML, validation, and release notes without renaming the project or protocol.

### Route selection

| Route | Use it when | Cost implication |
| --- | --- | --- |
| **Direct** | The task is small, isolated, and clear | No orchestration overhead; 0% routing saving |
| **Controller-only** | Planning, analysis, or review is needed without file changes | Uses only the controller layer |
| **Controller → efficient** | Scope is precise and the result is independently verifiable | Preferred for large amounts of clear execution |
| **Controller → complex** | Work spans modules, needs long context or shared-interface judgment, or carries high consequence | Uses the stronger capability profile |

The complex worker is not the efficient worker's manager and is not a permanent second controller. Both profiles are selected by the controller for the task's actual capability needs.

### How multiple executors cooperate

A complex run may use one or more workers, but parallelism follows **file ownership**, not agent count:

```text
Stage 1
├─ Complex A   → src/auth/core/*
├─ Efficient A → src/account/ui/*
└─ Efficient B → docs/account.md

Stage 2
└─ original designated owner → src/shared/routes.ts
```

Only tasks with completely disjoint write scopes may run together. Shared files have one designated owner. If dependencies, interfaces, or overlap are uncertain, the controller merges the work or schedules it sequentially.

No fixed worker count is promised. The controller launches the minimum useful number of executors in batches according to dependency order, live capacity, and safety boundaries.

## One complete evidence loop

1. **Extract requirements.** The controller gives every completion criterion a stable `REQ-ID` and required evidence.
2. **Plan.** The controller maps each task to Requirement IDs, a capability profile, dependencies, exact `write_scope`, exclusions, verification procedure, passing condition, and required evidence.
3. **Execute.** A worker changes only the assigned scope and does not rewrite the overall plan.
4. **Self-check.** The executor returns changed paths, Requirement coverage, tests, builds, or artifact evidence.
5. **Review.** The controller checks real files, the complete diff, verification quality, and requirement coverage before worker summaries.
6. **Decide.** The controller returns the closed verdict `PASS`, one focused `FIX`, or `BLOCKED`; non-gating suggestions remain separate.

A worker `PASS` applies only to its bounded task. Only the controller may approve the overall work.

## Non-negotiable boundaries

1. **One file, one owner.** Two workers never modify the same file in one run.
2. **Executors do not create subagents.** Complex and efficient workers are leaf nodes.
3. **No evidence, no completion.** Transport / spawn `completed` proves delivery only.
4. **Verification binds to the final candidate.** A later file change invalidates stale evidence.
5. **At most one focused fix.** The original owner repairs the original scope once; another failure becomes `BLOCKED`.
6. **Capability is not authorization.** Broader technical runtime access never expands user authorization or `write_scope`; disclose it and use Host-owned before/after snapshots to detect scope violations.
7. **Review standards do not fall.** Urgency, parallelism, or cost goals never replace verification and evidence.
8. **Worker PASS is not proof.** The controller reconstructs the success claim from real artifacts.
9. **A challenge is not a second controller.** It is read-only, cannot approve, and adds no fixed call cost to ordinary tasks.
10. **High-risk work still fails closed.** Block when model identity, fork, or required scope evidence is unprovable. Destructive, production, or irreversible external work additionally requires an enforceable matching boundary or explicit user approval for the broader capability.

### Bounded efficient-to-complex escalation

Only when an efficient worker's first failure occurs **before** any owned write may the controller escalate the same task and unchanged scope to the complex profile once.

The gate is zero-write state before the first failure.

After a worker writes an owned file, it retains ownership for the run. The controller may issue one focused fix to the original owner, but it may not hand the already-written file to another profile.

## Review outcomes

| Verdict | Meaning |
| --- | --- |
| `PASS` | Every completion criterion is supported by real files and fresh evidence |
| `FIX` | The original owner can make one focused correction without expanding scope |
| `BLOCKED` | Permissions, dependencies, runtime identity, scope, conflicts, or verification prevent a trustworthy delivery |

The three outcomes form a closed verdict vocabulary. Optional improvements and residual suggestions remain outside the verdict, but an unsatisfied `REQ-ID` can never be downgraded to a suggestion.

## When not to use it

The current Codex session is usually better for:

- a small change to one well-understood function;
- a localized typo, copy, or styling fix;
- code explanation, question answering, or short-form writing;
- work that cannot be divided into independent write scopes;
- tasks where orchestration, repeated context, and review cost more than implementation.

`$codex-prove` is not the default for everything. **Keep small work Direct; orchestrate only when complexity justifies it.**

## Install, check, and uninstall

### macOS / Linux

```sh
bash scripts/validate.sh
bash scripts/install.sh --check
bash scripts/install.sh

bash scripts/uninstall.sh
bash scripts/uninstall.sh --restore-latest
```

### Windows

```powershell
# Windows PowerShell 5.1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/validate.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/uninstall.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/uninstall.ps1 -RestoreLatest

# PowerShell 7
pwsh -NoProfile -File scripts/validate.ps1
pwsh -NoProfile -File scripts/install.ps1
pwsh -NoProfile -File scripts/uninstall.ps1
pwsh -NoProfile -File scripts/uninstall.ps1 -RestoreLatest
```

The lifecycle scripts manage only project-owned Skill and agent files. They preserve unrelated agents and the user's `~/.codex/config.toml`. Set `ORCHESTRATE_HOME` to a temporary home for isolated lifecycle tests.

The installer can migrate managed v0.1–v0.5 installs. It verifies the previous Skill, agents, and ownership state, backs them up, and atomically installs to `~/.agents/skills/codex-prove` and `~/.codex/codex-prove`. v1.0 also installs the `$sol-control` compatibility entry. `--restore-latest` restores the complete manageable pre-upgrade state. The installer refuses user-modified, unowned, or checksum-invalid collisions.

See [`docs/release/runtime-surface-matrix.md`](docs/release/runtime-surface-matrix.md) for platform and evidence coverage.

## Current status

The current version is **[v1.0.0](https://github.com/yehyakin/codex-prove/releases/tag/v1.0.0)**.

| Verification surface | Recorded evidence |
| --- | --- |
| Local repository | Both v1.0.0 Skill Creator entries, static validation, POSIX lifecycle checks, and all 115 tests pass; 39 Forward scenarios cover routing, ownership, evidence, and failure gates |
| Matched smoke | v0.5.0 recorded one matched live smoke; v1.0 changes branding, role names, and migration, so the old smoke is not presented as proof of the new agent names |
| Hosted CI | [POSIX workflow](https://github.com/yehyakin/codex-prove/actions/workflows/posix-validation.yml): Ubuntu/macOS × Python 3.11/3.13; [Windows workflow](https://github.com/yehyakin/codex-prove/actions/workflows/windows-validation.yml): Windows Server 2022 / `windows-latest` × Windows PowerShell 5.1 / PowerShell 7 |
| Physical Windows install | User-reported installation success; the Windows version, install log, and runtime identity payload were not captured, so this does not establish Native Nested |
| v1.0 runtime evidence | Fresh sessions discovered `$codex-prove` and the `$sol-control` compatibility entry; Host/tool mappings and two-turn handshakes passed for `prove-controller`, `prove-complex-worker`, and `prove-efficient-worker` |
| Runtime surface | Compatibility completed Controller planning, Host dispatch, and same-Controller final review with the new role names; Native Nested and physical Windows 11 runtime support remain separately unverified |

v1.0.0 decouples the brand, Skill, and agent roles from specific model names while retaining Requirement IDs, artifact-first review, verify-the-verifier checks, a bounded read-only challenge, and a resume packet. See the [v1.0.0 implementation report](CODEX_PROVE_V1_IMPLEMENTATION_REPORT.md) for the final evidence. The [historical implementation report](SOL_CONTROL_IMPLEMENTATION_REPORT.md) retains the model-branded release history.

These statements describe the recorded evidence boundary; they do not infer support for unverified runtime surfaces.

## Repository layout

```text
.agents/skills/
├─ codex-prove/                canonical Skill and invocation entry
│  ├─ SKILL.md
│  └─ references/
│     ├─ orchestration.md      orchestration contract
│     └─ runtime-notes.md      runtime and capability profiles
└─ sol-control/                explicit v1.0 compatibility entry

.codex/agents/
├─ prove-controller.toml
├─ prove-complex-worker.toml
└─ prove-efficient-worker.toml

scripts/
├─ validate.*
├─ install.*
├─ uninstall.*
└─ test.sh

tests/                         contracts, lifecycle, and forward cases
docs/                          release evidence, design records, and README assets
README.md                      Simplified Chinese
README.en.md                   English
```

## Documentation

- [Public Skill](.agents/skills/codex-prove/SKILL.md)
- [Orchestration contract](.agents/skills/codex-prove/references/orchestration.md)
- [Runtime and capability profiles](.agents/skills/codex-prove/references/runtime-notes.md)
- [Controller configuration](.codex/agents/prove-controller.toml)
- [Complex worker configuration](.codex/agents/prove-complex-worker.toml)
- [Efficient worker configuration](.codex/agents/prove-efficient-worker.toml)
- [Runtime surface matrix](docs/release/runtime-surface-matrix.md)
- [Real-project routing samples](tests/real-project-benchmark.md)
- [v1.0 matched A/B protocol](tests/v100-ab-benchmark.md)
- [v1.0 live matched smoke evidence](tests/v100-live-smoke.md)
- [v1.0 evidence-first implementation report](CODEX_PROVE_V1_IMPLEMENTATION_REPORT.md)
- [v0.4.0 implementation report](SOL_CONTROL_IMPLEMENTATION_REPORT.md)

## Maintainer and support

Primary maintainer: [@yehyakin](https://github.com/yehyakin). The project supports the latest tagged release and current `main`; see [SUPPORT.md](SUPPORT.md) for environment boundaries and help channels. Read [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before contributing, and use the structured [issue templates](https://github.com/yehyakin/codex-prove/issues/new/choose) for reproducible repository defects.

## Security

Do not open a public issue for security-sensitive behavior or attach tokens, private paths, or private repository content. Read [SECURITY.md](SECURITY.md) and submit a [private vulnerability report](https://github.com/yehyakin/codex-prove/security/advisories/new).

## Development and testing

Python 3.11 or newer is required.

```sh
bash scripts/validate.sh
bash scripts/test.sh
python3 scripts/benchmark_ab.py validate tests/fixtures/v100-ab-benchmark.json
```

`scripts/test.sh` selects an available Python 3.11+ interpreter and runs the complete `unittest` suite.
`benchmark_ab.py` only freezes the experiment, produces counterbalanced ordering, and summarizes complete cells. It never launches a model or declares a winner without measured cells.

When changing the README, update both languages and the documentation tests. Tests should protect facts, links, the rate snapshot, the formula, safety boundaries, and platform commands—not permanently lock one marketing message or one homepage section order.

## Limitations

- The cost ranges are budget projections based on public rates and example token shares, not matched A/B benchmarks.
- Real token volume may change because of planning, repeated context, verification, and rework.
- Fast mode, very long prompts, and different output ratios can change actual consumption.
- Exact custom-agent, model, reasoning-effort, and permission selection depends on the host runtime surface.
- Parallelism depends on live capacity and disjoint write scopes; no fixed worker count is promised.
- GitHub-hosted Windows runners prove Windows Server behavior, not physical Windows 11 behavior.
- The complex worker is an execution tier, not a second planner or controller.
- PROVE means evidence-bound verification, not a guarantee of perfect correctness.
- Final delivery depends on real files, the complete diff, and fresh verification. Configuration labels alone are not runtime evidence.

## License

This repository is licensed under the [Apache License 2.0](LICENSE). Attribution for reviewed prior art is recorded in [NOTICE](NOTICE).

**致谢 / Thanks**

Thank you to the [LINUX DO forum](https://linux.do/) community for its attention, feedback, and support.
