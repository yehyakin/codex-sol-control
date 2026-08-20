# Sol Control v0.5 evidence-first implementation report

Date: 2026-08-17

Repository: https://github.com/yehyakin/codex-sol-control

## 1. Final architecture

Sol remains the single controller, scheduler, conflict arbiter, and final
reviewer. Luna Max handles clear, low-ambiguity, falsifiable execution. Terra
High handles cross-module, long-context, ambiguous, or high-risk execution.
Neither worker may create subagents or approve the overall task.

The v0.5 evidence path is:

`REQ-ID -> Task -> Owner -> Files -> Verification -> Required evidence -> Sol verdict`

Worker `PASS` is an untrusted claim. Sol reviews the original request, real
changed paths, files, complete diff, verification artifacts, and Requirement
coverage before reading worker summaries.

## 2. Prior art and licenses

Pinned projects, license findings, and the boundary between design inspiration
and copied content are recorded in [NOTICE](NOTICE). The v0.5 research added
evaluation, recovery, evidence-graph, and adversarial-review references. No
third-party source code or text was copied into this implementation.

## 3. Adopted and rejected design

Adopted:

- stable Requirement IDs and falsifiable required evidence;
- artifact-first final review and verification-quality review;
- at most one selective, read-only challenge for qualifying work;
- forward-only resume state with owners, candidate identity, and attempt counts;
- explicit separation between runtime capability and user authorization;
- a reproducible matched A/B manifest and strict incomplete-cell rejection.

Rejected:

- a second Sol reviewer or permanent reviewer role;
- fixed challenge cost on ordinary tasks;
- trusting worker summaries, model self-reports, or test exit status alone;
- silent model, effort, permission, or role substitution;
- claiming an A/B winner from a protocol, one sample, or incomplete telemetry.

## 4. Routing

| Route | Boundary |
| --- | --- |
| Direct | Ordinary small work without explicit `$sol-control` invocation |
| Sol-only | Planning or review that needs no executor |
| Sol -> Luna | Clear, small-context, independently falsifiable work |
| Sol -> Terra | Cross-module, long-context, ambiguous, shared-interface, or high-risk work |

Ordinary work uses zero challenge calls. Qualifying high-consequence or
conflicting-evidence work may use at most one read-only challenge. Sol remains
the only final reviewer.

## 5. Native Nested and compatibility

Desktop Native Nested was exercised with fresh `fork_turns="none"` contexts.
Sol directly created Terra and Luna workers, retrieved structured results,
issued one bounded correction, used one qualifying challenge in the complex
audit, and returned the final verdict. Compatibility remains the fallback when
exact role selection or nesting cannot be proved.

## 6. Models and agents

| Agent | Model | Reasoning | Requested sandbox |
| --- | --- | --- | --- |
| `sol-controller` | `gpt-5.6-sol` | `high` | `read-only` |
| `terra-high-worker` | `gpt-5.6-terra` | `high` | `workspace-write` |
| `luna-max-worker` | `gpt-5.6-luna` | `max` | `workspace-write` |

The tested Desktop surface exposed broader technical filesystem capability than
the requested policy ceilings. v0.5 reports that capability instead of treating
it as authorization. Every live audit used `write_scope: []` plus Host-owned
baseline/final hashes. Destructive, production, credential-bearing, or
irreversible external work still requires an enforceable matching boundary or
explicit broader approval.

## 7. Main source changes

- Skill contract and two single-level references;
- all three custom-agent instructions;
- bilingual README and runtime matrix;
- 39 forward scenarios;
- deterministic A/B manifest, scheduler, validator, and summarizer;
- PowerShell uninstall rollback-order regression;
- v0.5 contract, benchmark, and lifecycle tests.

## 8. Installation and backups

The previous global installation and related configuration were copied before
installation to:

`/tmp/sol-control-v050-release-backup.9GVkcX`

Installer-created recovery backups include:

- `/Users/kin3/.codex/sol-control/backups/20260816T200705Z-71514`
- `/Users/kin3/.codex/sol-control/backups/20260816T201357Z-82995`

The installer updated only the owned Skill and three owned agent TOMLs. During
the v0.4.x to v0.5.0 migration it validated and backed up the owned compatibility
alias before removing it transactionally. It did not overwrite the complete
`config.toml` or unrelated agents. `install.sh --check` reported a consistent
installation.

## 9. Forward and static tests

The final local suite contains 136 tests. It covers Requirement/evidence gaps,
artifact-first review, wrong-scope verification, selective challenge, zero
challenge on ordinary work, resume idempotence, timeout ownership, capability
versus authorization, irreversible-work fail-closed behavior, installers, and
cross-platform lifecycle structure.

Final local result: `136/136 PASS`.

Skill Creator `quick_validate.py`, `scripts/validate.sh`, TOML/JSON parsing,
shell syntax, isolated POSIX install/check/uninstall, and `git diff --check`
also passed.

## 10. Real model calls

The complex Desktop run used Sol and Terra. The first attempt correctly failed
closed on an overly strict permission interpretation. After the contract was
fixed, Terra found a real PowerShell uninstall atomicity defect. A single
read-only challenge rejected one false lead and confirmed the real defect. The
Host fixed it and Sol returned `PASS` after inspecting the new candidate.

A separate low-risk run selected Luna Max, used zero challenges, preserved the
candidate, and ended in Sol `PASS`. Luna's first result needed one result-only
Requirement-coverage correction and the small task was noticeably slow; this is
recorded as a limitation rather than hidden.

## 11. Parallelism and ownership

The complex audit split independent installer and evidence-contract surfaces.
All live worker write scopes were empty. Baseline and final HEAD, status hash,
tracked diff hash, changed paths, and untracked hashes matched. No worker or Sol
modified the candidate during audit.

## 12. Failure and correction behavior

Observed failure classes included `permission`, `runtime`, `verification`, and
`evidence_quality`. The run did not accept transport completion, a worker PASS,
or the 135-test green result as sufficient proof. It repaired an incomplete
handshake exception, recovered from a stale inherited working directory by
keeping the same worker and scope, and used only bounded correction.

## 13. Fresh-session and matched smoke evidence

Fresh Desktop custom-agent contexts proved Sol, Terra, and Luna role selection,
model mapping, reasoning effort, nested result retrieval, and candidate binding.
The runtime matrix is in [runtime-surface-matrix.md](docs/release/runtime-surface-matrix.md).

One live matched CLI smoke pair is recorded in
[v050-live-smoke.md](tests/v050-live-smoke.md). The candidate passed the hidden
resume-interruption rubric while v0.4.1 did not. This is one ordered pair, not
the full benchmark and not a general winner claim.

## 14. Release state

Release version: `v0.5.0`.

The source now exposes only `$sol-control`; the v0.4.x `$sol-luna` compatibility
alias is absent from the repository and is removed safely during an owned
upgrade. The final commit, hosted CI runs, tag, and GitHub release bind this
report to the published candidate after the complete verification gate.

## 15. Known limitations

- Local `pwsh` is unavailable. PowerShell received deterministic structural and
  source-order checks, but the new failure-window test still requires Windows CI
  or a physical Windows run for dynamic proof.
- The full 48-cell by three-repetition matched A/B has not run. One live pair
  cannot support an overall quality, latency, token, or cost-saving percentage.
- Subscription-credit or currency cost was not exposed by the CLI, so live cost
  remains unavailable rather than inferred from tokens.
- Luna Max completed the bounded smoke successfully but was slow and needed one
  result-only correction. Sol should continue to reserve Luna for clear,
  falsifiable work.

## 16. Next evidence

- let GitHub Windows CI execute the new uninstall failpoint case;
- run more counterbalanced A/B cells only with an explicit spend budget;
- collect anonymous aggregate latency and retry data from real projects without
  publishing project names, paths, prompts, credentials, or source content.
