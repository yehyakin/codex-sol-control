# Sol Control v0.4.0 Implementation Report

Date: 2026-08-05

Repository: https://github.com/yehyakin/codex-sol-control

## 1. Final architecture

Sol Control keeps one controller and two bounded execution tiers:

```text
User goal
  -> Sol controls: understand, plan, assign, schedule, review
     -> Direct or Sol-only
     -> Luna Max for clear, low-ambiguity, falsifiable execution
     -> Terra High for cross-module, long-context, ambiguous, or high-risk execution
  -> Sol reviews real files, diff, tests, build, and evidence
  -> PASS, one focused FIX, or BLOCKED
```

Sol is the only controller. Terra High and Luna Max are leaf executors: neither may create
subagents, change the plan, or approve the overall task. Parallelism is allowed only for disjoint
write scopes. One file keeps one owner for the full run.

## 2. References and licenses

The implementation reviewed five projects at pinned commits. Their license status and use are
recorded in [NOTICE](NOTICE):

| Prior art | Reviewed license | Use in this project |
| --- | --- | --- |
| `joeke80215/orchestrate-sol-luna` | Apache-2.0 | role separation, fail-closed identity, evidence review concepts |
| `manhua-man/codex-parallel-subagent-planner` | no license detected | ideas only; no copied text or code |
| `yinguangyao/codex-dispatch-skill` | no license detected | ideas only; no copied text or code |
| `douglasmonsky/codex-orchestrate` | MIT | lifecycle, recovery, and conflict concepts |
| `Glaicer/subagent-orchestrator-skill` | MIT | architect/executor/reviewer and real-diff review concepts |

This repository uses Apache License 2.0. No source with missing license terms was copied.

## 3. Adopted and rejected design choices

Adopted:

- Sol as the single planner, scheduler, conflict arbiter, and final reviewer;
- precise task packets, one-file-one-owner, dependency stages, and live-capacity batching;
- model and reasoning-effort identity checks with fail-closed behavior;
- executor self-checks plus Sol review of real files and fresh evidence;
- at most one focused correction and resumable state for long work.

Rejected:

- forcing every task through subagents;
- fixed permanent teams or a public fixed worker count;
- a second controller, recursive workers, heavy dashboards, or unrelated model tiers;
- accepting summaries, spawn completion, or stale test output as delivery proof.

## 4. Routing contract

| Route | Boundary |
| --- | --- |
| Direct | Small, clear work where orchestration costs more than execution |
| Sol-only | Planning, analysis, or review without delegated implementation |
| Sol -> Luna | Clear, low-ambiguity, small-context, independently falsifiable work |
| Sol -> Terra | Cross-module, long-context, ambiguous debugging, shared interfaces, or high-risk implementation |

Luna may be upgraded to Terra exactly once only when Luna's first failure occurs before the first
write to an owned file. Terra's write state is never the escalation gate. After a write, Luna keeps
ownership and may receive one focused fix; otherwise the task is blocked.

## 5. Native Nested and Compatibility

Both runtime shapes share the same routing, packet, ownership, evidence, and review contract:

- Native Nested: main Codex -> Sol -> workers, only when nesting and exact identities are proven;
- Compatibility: main Codex creates workers from Sol's execution graph and returns evidence to Sol.

Compatibility is the verified baseline. Native Nested is never claimed solely from configuration
labels or successful spawn transport.

## 6. Model and agent configuration

| Agent | Model | Reasoning | Sandbox | Role |
| --- | --- | --- | --- | --- |
| `sol-controller` | `gpt-5.6-sol` | `high` | `read-only` | only controller and final reviewer |
| `terra-high-worker` | `gpt-5.6-terra` | `high` | `workspace-write` | bounded complex executor |
| `luna-max-worker` | `gpt-5.6-luna` | `max` | `workspace-write` | bounded clear-work executor |

The parent permission boundary remains authoritative. Model, agent type, reasoning effort, or
permission may not be silently substituted.

## 7. File structure

```text
.agents/skills/
  sol-control/                 canonical full Skill
  sol-luna/                    thin v0.4.x compatibility alias
.codex/agents/
  sol-controller.toml
  terra-high-worker.toml
  luna-max-worker.toml
scripts/
  install.sh / uninstall.sh / validate.sh
  install.ps1 / uninstall.ps1 / validate.ps1
tests/
docs/
README.md / README.en.md
NOTICE / LICENSE
```

The old `$sol-luna` entry is explicit-only, redirects to `$sol-control`, and is scheduled for
removal in v0.5.0. It does not contain or start a second orchestration implementation.

## 8. Installation and backup result

The v0.4 installer uses state version 3 under `~/.codex/sol-control`. It installs the canonical
Skill and the thin compatibility alias separately, hashes both, and preserves unrelated agents and
the complete `config.toml`.

Migration inputs are:

- v0.3 state under `~/.codex/sol-luna`;
- v0.1 state under `~/.codex/orchestrate-sol-luna`.

An external pre-change backup was created before repository edits at:

`/var/folders/4_/6qbh_56x08q9kk1thgr6b5yr0000gn/T/sol-control-migration.KpbhoT`

The final global installation result is recorded after release installation.

## 9. Forward tests

The fixture suite covers Direct, Sol-only, explicit Sol Control routing, independent parallel
work, shared-file conflict, staged dependencies, incomplete packets, missing evidence, stale
evidence, bounded correction, timeout/recovery behavior, result conflict, user steering,
unavailable model identity, Luna-to-Terra upgrade, and dirty-worktree preservation.

The v0.4 local candidate currently records **112/112 tests PASS** through `scripts/test.sh`.

## 10. Real model calls

Compatibility routing was previously exercised with the configured Sol, Terra, and Luna agent
roles. A fresh-session discovery and invocation check for the renamed `$sol-control` surface is
performed only after the stable source is installed globally. Native Nested remains unproven until
the runtime returns exact child model and reasoning identity evidence.

## 11. Parallel and write-conflict tests

Contract fixtures prove that independent scopes may launch in parallel, shared integration files
have one owner, and dependent work runs in stages. No test writes to a business repository; all
lifecycle execution uses isolated temporary homes.

## 12. Failure and downgrade tests

The lifecycle suite covers:

- modified owned-target refusal;
- unowned-target refusal;
- injected failure after replacement and after state write;
- exact rollback of v0.1 and v0.3 inputs;
- missing or malformed manifest fields;
- stale evidence and missing structured results;
- model identity unavailable -> fail closed.

The installer never changes the complete Codex configuration and never silently changes models.

## 13. Fresh-session discovery

Pending final global installation. The acceptance check requires a new Codex session to discover
`$sol-control`, keep `$sol-luna` as an explicit compatibility alias, and avoid implicit invocation.

## 14. GitHub commit and version

Release target: `v0.4.0` on `main` at
https://github.com/yehyakin/codex-sol-control. Final commit, hosted POSIX/Windows CI, repository
rename, and annotated tag are recorded after they exist.

## 15. Known limitations

- Cost ranges are scenario-model projections, not matched A/B elapsed-time benchmarks.
- Runtime identity proof depends on the active Codex surface.
- Hosted Windows runners do not prove physical Windows 11 behavior.
- Native Nested remains unproven unless exact nested model and effort identity are returned.
- `$sol-luna` is temporary compatibility and will be removed in v0.5.0.

## 16. Follow-up recommendations

- collect anonymized, matched route/token/time observations for cost and latency calibration;
- run the same v0.4 tag on a physical Windows 11 machine and retain non-sensitive evidence;
- remove the compatibility alias in v0.5.0 after a documented deprecation window;
- keep README status tied to real commits and hosted run URLs instead of reusing older evidence.
