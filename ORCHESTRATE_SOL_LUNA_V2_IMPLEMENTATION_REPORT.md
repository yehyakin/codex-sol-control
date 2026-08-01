# Sol Luna v0.2 Implementation Report

Date: 2026-08-02

Repository: https://github.com/yehyakin/codex-sol-luna-orchestrator

Release candidate: `v0.2.0` (pending final report commit, tag, and push)

## 1. Final architecture

The public model has two roles:

```text
User goal
  -> Sol controls the work
     -> one or more Luna Max workers execute bounded tasks
     -> Sol reviews real files, diffs, and verification evidence
```

Sol understands the goal, defines completion, splits and assigns work,
schedules dependency stages, arbitrates conflicts, and decides `PASS`, `FIX`,
or `BLOCKED`. Luna Max executes one complete task packet, stays inside its write
scope, self-checks, and returns evidence. It cannot create subagents or approve
the overall result.

The runtime Host retains authorization, workspace safety, dispatch mechanics,
integration, and the user reply. Those responsibilities do not create a third
public orchestration role.

## 2. Reference projects and licenses

| Reviewed project snapshot | Detected license | Use |
| --- | --- | --- |
| `joeke80215/orchestrate-sol-luna@eba163a` | Apache-2.0 | Role separation, evidence gates, exact-selection ideas. |
| `manhua-man/codex-parallel-subagent-planner@ea3d8db` | No license file detected | Ideas only; no text or code copied. |
| `yinguangyao/codex-dispatch-skill@00630de` | No license file detected | Ideas only; no text or code copied. |
| `douglasmonsky/codex-orchestrate@f2954a0` | MIT | Ideas only; no source copied. |
| `Glaicer/subagent-orchestrator-skill@96eaeb1` | MIT | Ideas only; no source copied. |

The audit inspected actual Skill files, agent definitions, references, and
available validation material rather than relying only on README summaries.
This repository is Apache-2.0. README and NOTICE preserve the prior-art and
license distinctions.

## 3. Designs absorbed and rejected

Absorbed: one controller, bounded workers, fresh contexts, exact model and
reasoning proof, fail-closed dispatch, dynamic capacity, dependency stages,
exclusive file ownership, falsifiable verification, actual Diff review, one
focused fix, transactional installation, and dirty-worktree preservation.

Rejected: public routing levels, public runtime-mode taxonomy, a third Main
orchestration role, fixed worker counts, mandatory delegation, permanent agent
fleets, dashboards, heavy ledgers, unrelated model tiers, and business-specific
workflows.

## 4. Routing behavior

- Ordinary simple work remains direct when `$sol-luna` is not explicitly
  invoked.
- Explicit `$sol-luna` starts Sol.
- Planning-only work may finish with Sol and zero Luna workers.
- Execution uses the minimum useful number of Luna workers.
- Ready tasks launch only up to current live capacity; excess work waits for a
  later batch.
- Independent, disjoint writes may run together. Dependencies and overlapping
  writes run in later stages.

The Skill promises no fixed Luna maximum.

## 5. Runtime dispatch

The proven route is Host-dispatched: Sol produces the plan, the Host launches
Luna with that plan, and Sol reviews the returned evidence and actual
workspace. This is an internal transport detail, not a public mode.

Direct nested Sol-to-Luna custom-agent launch was not proven by the current
tool surface. The package therefore does not claim it and remains fail-closed
when exact nested selection cannot be observed.

## 6. Model and agent configuration

| Agent | Model | Reasoning | Sandbox ceiling | Role |
| --- | --- | --- | --- | --- |
| `sol-controller` | `gpt-5.6-sol` | `high` | `read-only` | Controller and final reviewer. |
| `luna-max-worker` | `gpt-5.6-luna` | `max` | `workspace-write` | Bounded execution; no subagents. |

Exact runtime banners were observed for Sol/high/read-only and
Luna/max/workspace-write. Agent names or TOML text alone were not accepted as
runtime proof. No model, effort, or permission substitution was used.

## 7. Repository structure

```text
.agents/skills/sol-luna/
  SKILL.md
  agents/openai.yaml
  references/orchestration.md
  references/runtime-notes.md
.codex/agents/
  sol-controller.toml
  luna-max-worker.toml
scripts/
tests/
README.md
NOTICE
LICENSE
```

The Skill entrypoint is concise, its two references are one level deep, and
test reports remain outside runtime Skill context.

## 8. Installation and backups

Pre-upgrade external backup:
`/tmp/sol-luna-v020-backup.ZOme28`

Installer backup:
`/Users/kin3/.codex/sol-luna/backups/20260801T202931Z-90567`

Installed targets:

- `/Users/kin3/.agents/skills/sol-luna`
- `/Users/kin3/.codex/agents/sol-controller.toml`
- `/Users/kin3/.codex/agents/luna-max-worker.toml`

Repository and installed Skill trees compare equal, and both agent TOMLs match
byte-for-byte. The unmodified v0.1 Skill and Sol paths were migrated. Unrelated
agents were preserved. The `config.toml` SHA-256 was identical before and after
installation; its contents were neither replaced nor reported.

## 9. Forward tests

The lean v0.2 matrix contains ten scenarios: ordinary direct work, explicit
execution, planning-only zero Luna, single-file ownership, live-capacity
batching, shared integration ownership, incomplete packet blocking, unavailable
exact selection, one focused fix, and dirty-worktree preservation.

The final repository suite ran 21 tests with 21 PASS and zero failures. It also
exercised isolated v0.1 migration, modified-target preservation, install
rollback, uninstall refusal after user modification, restore-latest,
unrelated-file preservation, and `config.toml` integrity.

## 10. Real model calls

- Fresh Sol planning and review used `gpt-5.6-sol`, high reasoning, and
  read-only access.
- The bounded repair worker used `gpt-5.6-luna`, max reasoning, and
  workspace-write access in session
  `019fbefd-daef-7f10-a0a4-9ea9597b0bd6`.
- A fresh global discovery session used exact Sol/high/read-only in session
  `019fbf04-ffb1-7c42-81b1-86cd469418f5`.

The real repair changed only the intended validator expression, ran all three
required commands, and returned exact evidence. The Host/parent independently reran the
commands before Sol returned `PASS`.

## 11. Parallelism and write conflicts

During the upgrade, two Luna work streams were launched concurrently for
disjoint core and script scopes. The core worker encountered protected hidden
directories and returned `BLOCKED` without a write; Sol reassigned the untouched
scope rather than pretending success. The script worker retained ownership of
the lifecycle scripts.

The contract permits parallel disjoint work, prevents two writers on one file,
assigns one owner to shared integration files, and batches excess independent
tasks when live capacity is lower than the ready frontier.

## 12. Failure and recovery evidence

The first integrated run exposed an undefined Python `SKILL_ROOT` reference in
`validate.sh`. After its permitted correction budget had been used, Sol returned
`BLOCKED`; the result was reported without installing or publishing.

The user then explicitly authorized a new repair run. Its first Sol planning
call timed out and was recorded; one fresh Sol retry produced a single-file
packet. Luna traced the quoted shell/Python boundary, used the already-passed
`skill_file.parent`, and preserved the forbidden-term check. Repository
validation and all 21 tests passed, then Sol reviewed the real file and evidence
and returned `PASS`.

This demonstrates bounded retry, real blocking, new-run authorization, scoped
ownership, and evidence-based recovery rather than retry-until-green behavior.

## 13. Fresh-session discovery

A new ephemeral Codex session started in a temporary directory, outside the
source repository, and read the globally installed Skill. For a planning-only
prompt it returned:

```text
skill_discovered=yes
controller=Sol
luna_count=0
route_result=PASS
```

No files or external systems were changed by the probe.

## 14. GitHub commit and version

- Baseline: `v0.1.0` at `1350ceae58eec3c55a8139488a799518a5d437bb`
- v0.2 contract-test commit: `21cc922bd05288bed4cd1898527c32987633413e`
- v0.2 implementation commit: `059e2c473430e389626e6898f53100eb8b2cda5b`
- Development branch: `codex/v0.2-sol-luna-simplification`
- Planned release tag: `v0.2.0`, to be applied to the final report-bearing
  release commit after this report is committed
- Remote: https://github.com/yehyakin/codex-sol-luna-orchestrator

At report-write time, the v0.2 branch, report commit, tag, and push are pending.
GitHub remains the source of truth after publication; global paths are
installation copies.

## 15. Known limitations

1. Direct nested Sol-to-Luna launch is unproven. The tested Host-dispatched
   route is used, and exact selection remains fail-closed.
2. `pwsh` is unavailable on this iMac. `install.ps1` passed deterministic
   structural checks but not a Windows execution or PowerShell AST run.
3. `skill-creator`'s `quick_validate.py` requires PyYAML, which was not bundled
   in either available Python. PyYAML was installed only into an external
   temporary validation directory; the official validator then returned
   `Skill is valid!`. No global Python dependency was modified.
4. Live worker capacity is runtime-dependent. The Skill intentionally promises
   no fixed Luna count.

## 16. Recommendations

- Add Windows CI with `pwsh`, AST parsing, and isolated lifecycle tests.
- Add a direct nested-launch probe only when the runtime exposes observable
  custom-agent identity, model, effort, permissions, and nesting evidence.
- Keep future changes repository-first, validate with Skill Creator and the
  full suite, reinstall atomically, and retain the Sol review gate.
