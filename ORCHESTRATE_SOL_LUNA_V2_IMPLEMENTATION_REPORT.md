# Sol Luna v0.3.0 Implementation Report

Date: 2026-08-02

Repository: https://github.com/yehyakin/codex-sol-luna

Release: `v0.3.0`

## 1. Final architecture

The public architecture deliberately has only two model roles:

```text
User goal
  -> Sol controls, plans, assigns, and reviews
     -> one or more Luna Max workers execute bounded tasks
  -> Sol inspects real files, diffs, and evidence
  -> Codex host enforces authorization and delivers the result
```

Sol is the sole controller. Luna Max is the bounded executor. The Codex host
retains user authorization, workspace safety, dispatch mechanics, and the final
reply, but it is not presented as a third orchestration role. The package is not
a fixed agent team or a general-purpose multi-role framework.

## 2. Reference projects and licenses

| Reviewed project snapshot | Detected license | Use |
| --- | --- | --- |
| `joeke80215/orchestrate-sol-luna@eba163a` | Apache-2.0 | Role separation, evidence gates, exact-selection ideas. |
| `manhua-man/codex-parallel-subagent-planner@ea3d8db` | No license file detected | Ideas only; no text or code copied. |
| `yinguangyao/codex-dispatch-skill@00630de` | No license file detected | Ideas only; no text or code copied. |
| `douglasmonsky/codex-orchestrate@f2954a0` | MIT | Ideas only; no source copied. |
| `Glaicer/subagent-orchestrator-skill@96eaeb1` | MIT | Ideas only; no source copied. |

The audit inspected the actual Skill files, agent definitions, references, and
available validation material instead of relying only on README summaries.
Unlicensed sources informed ideas only. This project is Apache-2.0; `NOTICE`
and both README files preserve the prior-art and license distinctions.

## 3. Designs absorbed and rejected

Absorbed: one controller, bounded workers, fresh model contexts, fail-closed
model selection, dynamic live capacity, dependency stages, exclusive file
ownership, falsifiable verification, real Diff review, one focused correction,
transactional installation, dirty-worktree preservation, and recoverable
Windows lifecycle operations.

Rejected: public multi-role teams, a third planning role, fixed worker counts,
mandatory delegation, permanent agent fleets, heavy dashboards or ledgers,
unrelated model tiers, and business-specific workflows.

## 4. Routing behavior

- **Direct:** ordinary simple work stays with the current Codex when the Skill
  is not explicitly invoked. It creates neither Sol nor Luna and claims zero
  routing savings.
- **Sol planning-only:** explicit `$sol-luna` starts Sol, but a task that only
  needs analysis or a plan may finish with zero Luna workers.
- **Sol to Luna:** bounded implementation, audit, or verification packets go to
  the minimum useful number of Luna workers. Independent non-overlapping tasks
  may share a stage; dependencies and overlapping writes move to later stages.
- **High consequence:** Sol defines checkpoints, exact ownership, verification,
  and stop conditions before execution. External high-risk actions still
  require explicit user authorization.

The Skill promises no fixed Luna maximum. Runtime live capacity is the ceiling;
excess ready tasks wait for the next batch.

## 5. Compatibility and Native Nested

The proven route is Compatibility dispatch:

```text
Host -> Sol plan -> Host launches Luna -> Sol reviews -> Host delivers
```

This route was used for the v0.3.0 work: Sol approved bounded task packets,
Luna executed within a unique write scope, and Sol reviewed the actual Diff and
fresh verification evidence.

Native Nested Sol-to-Luna custom-agent launch remains unproven on the current
tool surface. The package does not claim it and fails closed when exact nested
model, effort, permission, or identity selection cannot be observed.

## 6. Model and agent configuration

| Agent | Model | Reasoning | Sandbox ceiling | Role |
| --- | --- | --- | --- | --- |
| `sol-controller` | `gpt-5.6-sol` | `high` | `read-only` | Controller, planner, router, and final reviewer. |
| `luna-max-worker` | `gpt-5.6-luna` | `max` | `workspace-write` | One bounded execution packet; no subagents. |

Fresh runtime banners proved both exact models and reasoning efforts. Agent
names or TOML text alone were not accepted as runtime proof. No silent model,
effort, agent type, or permission substitution was used.

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
.github/workflows/windows-validation.yml
docs/assets/
scripts/
tests/
README.md
README.zh-CN.md
NOTICE
LICENSE
```

The Skill entrypoint stays concise. Detailed runtime rules are one reference
level deep. Test plans and reports remain outside the runtime Skill context.
The English and Chinese README files use the same architecture, installation,
Windows support, validation, pricing, and limitation facts.

## 8. Installation and backups

The v0.3.0 source was atomically installed on the iMac at:

- `/Users/kin3/.agents/skills/sol-luna`
- `/Users/kin3/.codex/agents/sol-controller.toml`
- `/Users/kin3/.codex/agents/luna-max-worker.toml`

Recoverable installer backup:
`/Users/kin3/.codex/sol-luna/backups/20260801T234410Z-55952`

The installed Skill tree and both agent TOMLs match the repository copies.
Unrelated agent files were preserved. The installer's backup manifest recorded
the pre-install `config.toml` hash, and the post-install hash was identical; the
installer did not overwrite the complete configuration.

## 9. Forward and repository tests

The routing contract covers direct work, planning-only zero-Luna work, bounded
execution, dynamic capacity, non-overlapping parallel stages, dependency
stages, single-file ownership, shared integration ownership, incomplete packet
blocking, exact-model failure, one focused correction, conflict review, and
dirty-worktree preservation.

Fresh local evidence:

- `python3.13 -m unittest discover -s tests -q`: 39 tests, 39 PASS.
- `bash scripts/validate.sh`: `Validation: PASS`.
- Isolated negative probes removed each newly required v0.3 artifact in turn;
  the standalone validator rejected all eight cases.
- Skill Creator validator: PASS during package validation.
- `actionlint`: PASS for the Windows workflow.
- `git diff --check`: PASS.

The installer suites use temporary homes and simulated artifacts. No business
repository was used or modified.

## 10. Real model calls

- The upgrade used exact Sol/high/read-only for planning and real-Diff review.
- A bounded exact Luna/max worker implemented the final one-file Windows test
  routing correction and returned verification evidence.
- Fresh installed-Skill discovery used `gpt-5.6-sol`, high, read-only in session
  `019fbfb7-91d8-7f42-90b3-be292ca2cb6f`; it returned
  `skill_discovered=yes`, `controller=Sol`, `luna_count=0`, and
  `route_result=PASS`.
- Fresh Luna availability used `gpt-5.6-luna`, max in session
  `019fbfb8-0328-7ab3-905a-8403bc6da8a1`; it found the installed worker
  configuration, confirmed recursive delegation is forbidden, and returned
  `probe_result=PASS`.

These calls prove Compatibility dispatch and the availability of both models.
They do not prove Native Nested dispatch.

## 11. Parallelism and write conflicts

Sol assigns one owner to every writable file for the entire run. Multiple Luna
workers may read the same file, but overlapping or uncertain writes are merged
or scheduled sequentially. Independent, disjoint work may run concurrently up
to live capacity. Shared integration files have one named owner.

The v0.3.0 upgrade used separate bounded work streams only when their scopes
were disjoint. The final Windows correction owned only
`tests/test_installers.py`; Sol verified that the real Diff contained exactly
eight insertions in that one file before permitting commit and push.

## 12. Failure, degradation, and Windows evidence

Windows work used an evidence-driven correction sequence. Each failed CI run
was treated as a concrete result, narrowed to one cause, and sent through a
bounded correction packet. It fixed PowerShell variable case-insensitivity,
PowerShell 5.1 Python marshalling, literal `$sol-luna` quoting, state-key
parsing, hashtable splatting, restore assertions, and POSIX-only Bash test
routing without weakening the native Windows lifecycle gate.

Final Windows run:
https://github.com/yehyakin/codex-sol-luna/actions/runs/30724456350

All four jobs passed:

- Windows Server 2022 with Windows PowerShell 5.1.
- Windows Server 2022 with PowerShell 7 (`pwsh`).
- Windows Server 2025 (`windows-latest`) with Windows PowerShell 5.1.
- Windows Server 2025 (`windows-latest`) with PowerShell 7.

Every job passed native PowerShell syntax parsing, `validate.ps1`, the complete
install/uninstall/restore lifecycle, and Python discovery. Python ran all 39
tests with 11 explicit POSIX-runtime skips and no WSL dependency; the three
Windows static contract tests remained active.

## 13. Fresh-session discovery

A new ephemeral Codex session started in a temporary directory outside the
repository, loaded `/Users/kin3/.agents/skills/sol-luna/SKILL.md`, and returned:

```text
skill_discovered=yes
controller=Sol
luna_count=0
route_result=PASS
```

The probe was read-only and planning-only. A separate fresh Luna session proved
the installed worker configuration and exact Luna/max runtime. Neither probe
modified files or accessed external systems.

## 14. GitHub project and version

- Canonical repository: https://github.com/yehyakin/codex-sol-luna
- Previous repository name: `codex-sol-luna-orchestrator` (renamed in place;
  GitHub preserves redirects).
- Development branch: `codex/rename-to-codex-sol-luna`.
- Windows-green validator commit: `0ed1d9d`.
- Stable version: `v0.3.0` on the merged release commit.
- Earlier stable tags remain `v0.1.0` and `v0.2.0`.

GitHub remains the only source repository. The global Skill and agent paths are
installation copies.

## 15. Cost estimate and known limitations

Official short-context pricing at implementation time:

| Model | Input / 1M | Cached input / 1M | Cache write / 1M | Output / 1M |
| --- | ---: | ---: | ---: | ---: |
| GPT-5.6 Sol | $5.00 | $0.50 | $6.25 | $30.00 |
| GPT-5.6 Luna | $0.20 | $0.02 | $0.25 | $1.20 |

Luna is `1/25` of Sol across these listed token categories, so an otherwise
identical delegated segment is about 96% cheaper. Whole-workflow savings are:

```text
savings = delegated_share * (1 - luna_duplication / 25) - sol_overhead
```

| Scenario | Delegated share | Luna duplication | Added Sol overhead | Estimated workflow saving |
| --- | ---: | ---: | ---: | ---: |
| Conservative | 50% | 125% | 10% | about 38% |
| Typical | 70% | 115% | 8% | about 59% |
| Execution-heavy | 85% | 110% | 7% | about 74% |

For 1M input plus 0.1M output, an all-Sol reference is about $8.00 or
200 ChatGPT credits. The typical routed scenario is about $3.30 or 82.44
credits. These are transparent planning estimates, not usage guarantees or
benchmarks. Direct work saves 0% through routing, and poor task splits,
duplicate context, retries, or heavy Sol review can reduce or erase the saving.
API dollars and ChatGPT subscription credits/capacity are different accounting
surfaces. Sources: https://developers.openai.com/api/docs/pricing and
https://learn.chatgpt.com/docs/pricing.

Known limitations:

1. Native Nested is unproven; Compatibility is the tested mode.
2. Windows Server 2022/2025 is proven in hosted CI. Native Windows 11 has not
   yet been run on a dedicated Windows 11 machine and is not claimed as proven.
3. A `v0.2` RestoreLatest path can restore canonical files without recreating a
   current ownership-state file. The restored bytes are correct, but a later
   managed uninstall may require a fresh install to re-establish ownership
   state.
4. GitHub currently emits a non-failing Node.js action-runtime deprecation
   annotation for `actions/checkout@v4` and `actions/setup-python@v5` while
   forcing Node.js 24. This does not affect the Windows test result but should
   be removed in a later dependency-only update.

## 16. Recommendations

- Run the isolated lifecycle harness once on a real Windows 11 machine before
  claiming native Windows 11 evidence.
- Add a Native Nested probe only when the runtime exposes observable custom
  agent identity, model, effort, permissions, and nesting evidence.
- Re-establish managed ownership with a fresh install after restoring a prior
  v0.2 installation.
- Update GitHub action major versions in a separate, fully revalidated change.
- Continue repository-first development, atomic installation, exact-model
  fail-closed routing, and Sol review of real artifacts.
