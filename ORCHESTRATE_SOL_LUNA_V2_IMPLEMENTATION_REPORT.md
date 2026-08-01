# Orchestrate Sol Luna V2 Implementation Report

Date: 2026-08-01

Repository: https://github.com/yehyakin/codex-sol-luna-orchestrator

Core implementation commit: `a3b6af82a9bafddf9d136989a9abc7428584a065`

Release target: `v0.1.0`

## 1. Final architecture

The package implements one adaptive route owned by Main:

```text
User request
  -> Main classifies complexity
     -> Level 0: Main executes directly
     -> Level 1: Sol assists; Main executes
     -> Level 2/3: Sol plans -> Luna executes -> Sol reviews -> Main integrates
```

Main always owns authorization, workspace safety, dispatch, integration, final verification, and the user reply. Sol is the read-only planner and evidence reviewer. Luna is a bounded worker that cannot create subagents or approve its own result.

## 2. Reference projects and licenses

| Project snapshot | Detected license | Use in this repository |
| --- | --- | --- |
| `joeke80215/orchestrate-sol-luna@eba163a` | Apache-2.0 | Ideas and protocol comparison; no source code copied. |
| `manhua-man/codex-parallel-subagent-planner@ea3d8db` | No license file detected | Ideas only; no text or code copied. |
| `yinguangyao/codex-dispatch-skill@00630de` | No license file detected | Ideas only; no text or code copied. |
| `douglasmonsky/codex-orchestrate@f2954a0` | MIT | Ideas only; no source code copied. |
| `Glaicer/subagent-orchestrator-skill@96eaeb1` | MIT | Ideas only; no source code copied. |

The audit read actual Skill files, agent definitions, references, and validators/tests where present, not only README files. This repository uses Apache License 2.0. README and NOTICE preserve the prior-art and license distinctions without claiming the underlying concepts as original.

## 3. Designs absorbed and rejected

Absorbed: strict Sol/Luna role separation, fresh-context role switching, exact-model fail-closed behavior, task graphs, dependency waves, read/write scopes, exclusive writers, falsifiable verification, bounded correction, actual Diff review, conflict arbitration, recoverable state, and Main-owned integration.

Rejected: mandatory delegation for small tasks, a fixed all-serial three-role pipeline, permanent agent fleets, unrelated model tiers, dashboards, heavy ledgers, marketing/history text, and any project-specific workflow.

## 4. Routing levels

- Level 0 / Direct: narrow, deterministic work; zero delegation.
- Level 1 / Sol Assist: complex reasoning without useful parallel execution; one Sol and no forced Luna.
- Level 2 / Sol to Luna: multi-file or multi-module work with bounded execution and unified review.
- Level 3 / High-Risk: authorization, recovery checkpoint, exclusive ownership, stop conditions, and mandatory Sol review.

The default worker count is 1-3 and cannot exceed the active runtime cap.

## 5. Native Nested and Compatibility

Compatibility is the proven default: Main launches Sol, Main launches Luna from the approved packet, and Main returns actual results to Sol for final review. A real Compatibility route passed end to end.

Native Nested remains fail-closed. The current config had no explicit max-depth override, and the runtime did not provide live proof of effective depth at least two plus nested Luna identity/model/effort/permission selection. Configuration text alone was not accepted as proof.

## 6. Model and agent configuration

| Agent | Model | Reasoning | Configured sandbox | Boundary |
| --- | --- | --- | --- | --- |
| `sol-planner` | `gpt-5.6-sol` | `high` | `read-only` | Plans and reviews; no bulk implementation. |
| `luna-max-worker` | `gpt-5.6-luna` | `max` | `workspace-write` ceiling | Intersects with parent permission; no subagents. |

Fresh runtime banners proved exact Sol/high and Luna/max calls. A fresh read-only parent discovered both installed custom agents; Luna's effective sandbox was reduced to read-only, demonstrating that the child definition did not widen parent authority.

The active desktop task exposed four total concurrency slots. No repository or global config edit was made to raise thread or nesting limits.

## 7. File structure

The repository contains the concise Skill entrypoint, one routing reference, two agent TOMLs, shell/PowerShell lifecycle scripts, fixtures, tests, README, NOTICE, LICENSE, and this report. Forward-test results remain under `tests/`; they are not copied into Skill runtime context.

## 8. Installation and backups

Phase 1 external safety backup: `/tmp/codex-sol-luna-backup.7Big0r`.

Installed targets:

- `/Users/kin3/.agents/skills/orchestrate-sol-luna`
- `/Users/kin3/.codex/agents/sol-planner.toml`
- `/Users/kin3/.codex/agents/luna-max-worker.toml`

Installer backup: `/Users/kin3/.codex/orchestrate-sol-luna/backups/20260801T131819Z-61811`.

All three installed targets compare equal to repository source. The live `config.toml` SHA-256 remained `0714bd5bcbd9635bb2fb0dc09c1e1eac5edc7874858288ab7f0baee7c63c7ddd` before and after installation. The installer did not overwrite the full config or unrelated agents.

## 9. Forward Test results

All 13 required scenarios were evaluated. Twelve produced PASS. The Native Nested scenario produced the required fail-closed BLOCKED result because its live prerequisites were not proved. This is correct behavior, not a failed Compatibility route.

Static verification passed:

- repository validator: PASS;
- Python 3.12 contract/installer suite: 17 tests, all PASS;
- TOML parsing: PASS;
- YAML parsing on the iMac Ruby runtime: PASS;
- Bash syntax: PASS;
- Git whitespace: PASS;
- PowerShell deterministic structural checks: PASS.

## 10. Real model calls

The live Compatibility fixture used only a temporary synthetic Git repository:

1. Exact `gpt-5.6-sol/high/read-only` generated a canonical graph and two disjoint Luna packets.
2. Two exact `gpt-5.6-luna/max/workspace-write` workers ran concurrently and changed one exclusive file each.
3. Each Luna returned exact-byte and targeted-unittest evidence.
4. Main verified the full two-test suite, complete Diff, exact bytes, unchanged tests, and whitespace.
5. A fresh exact `gpt-5.6-sol/high/read-only` reviewed the real files and Diff and returned PASS with high evidence quality.

No real business repository was used by the fixture.

## 11. Parallel and write-conflict tests

The live route proved parallel disjoint writes. The same-file fixture forbids concurrent writers: read-only alternatives may run in parallel, Sol selects a solution, and exactly one task receives write ownership. The dependency fixture schedules database, API, and frontend-shaped synthetic work in ordered waves.

## 12. Failure and downgrade tests

The suite covers missing Luna evidence, timeout, conflicting returns, omitted requirements, unavailable exact model, dirty worktree preservation, and installer failure after replacement. Missing evidence triggers a Correction Packet, the same narrow issue may be retried at most once, and unavailable identity/model proof fails closed. Installer fault injection restored all prior exact targets and preserved unrelated files and config.

## 13. Fresh-session discovery

A new ephemeral Codex session loaded the installed `$orchestrate-sol-luna` Skill and returned `Level 0 / delegation 0` for a simulated one-line copy edit. A separate fresh-session probe discovered and called both installed custom agent types with their exact pinned models and reasoning efforts.

## 14. GitHub commit and version

- Branch: `main`
- Baseline commit: `e78f5ea49d92a9aa7328926bb472fd1e33867752`
- Core implementation commit: `a3b6af82a9bafddf9d136989a9abc7428584a065`
- Release tag: `v0.1.0`, applied to the final report-bearing commit after final verification
- Remote: https://github.com/yehyakin/codex-sol-luna-orchestrator

GitHub is the source of truth. The global directories are installation copies only.

## 15. Known limitations

1. Native Nested is not enabled because effective depth at least two and exact nested launch behavior were not live-proved.
2. `pwsh` is not installed on this iMac, so `install.ps1` received structural checks but no Windows execution or PowerShell AST run.
3. The requested literal `skill-creator` Skill was not installed or callable. The available `writing-skills` workflow, TDD, repository contract tests, and validator were used instead. Literal Skill Creator validation is not claimed.
4. The system `/usr/bin/python3` is 3.9; full tests require Python 3.11+ and were run with the Codex-bundled Python 3.12.13.

## 16. Recommendations

- Add Windows CI with `pwsh`, AST parsing, and isolated install/rollback tests.
- Re-run the Native Nested probe only after the runtime exposes and proves depth at least two.
- Keep future protocol changes repository-first, rerun all validators and forward cases, then reinstall atomically.
