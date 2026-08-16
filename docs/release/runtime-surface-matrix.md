# Runtime surface matrix

Release-time documentation for Sol Control. This matrix is not a
per-task checklist and does not turn configuration text into runtime proof.
Statuses are limited to `VERIFIED`, `FAILED`, and `UNVERIFIED`.

Date: 2026-08-17

| Surface | Signal | Status | Evidence location | Date |
| --- | --- | --- | --- | --- |
| Desktop | Agent selection | VERIFIED | Host launch records selected `sol-controller`, `terra-high-worker`, and `luna-max-worker` with `fork_turns="none"`; child paths matched each requested role | 2026-08-17 |
| Desktop | exact model | VERIFIED | Authoritative Host/tool mapping fixed Sol to `gpt-5.6-sol`, Terra to `gpt-5.6-terra`, and Luna to `gpt-5.6-luna` | 2026-08-17 |
| Desktop | reasoning | VERIFIED | Authoritative Host/tool mapping fixed Sol/Terra/Luna efforts to `high` / `high` / `max` | 2026-08-17 |
| Desktop | nested dispatch | VERIFIED | `sol-controller` directly created two independent `terra-high-worker` audits, one bounded `luna-max-worker` smoke, and one qualifying read-only challenge | 2026-08-17 |
| Desktop | result retrieval | VERIFIED | Terra exposed a PowerShell rollback defect; the challenge confirmed it and rejected a false lead; after correction Sol returned `PASS`. The separate Luna smoke also ended in Sol `PASS` | 2026-08-17 |
| Desktop | candidate binding | VERIFIED | Host and Sol matched HEAD `582200cfb5b2d83a31bc93fcbf96915f0ac8c393`, status SHA-256, tracked diff SHA-256, changed paths, and five untracked file hashes before and after worker execution | 2026-08-17 |
| CLI | Agent selection | UNVERIFIED | No CLI runtime identity payload captured in this release | 2026-08-03 |
| CLI | exact model | UNVERIFIED | Configuration names are not runtime proof | 2026-08-03 |
| CLI | reasoning | UNVERIFIED | No CLI reasoning-effort payload captured | 2026-08-03 |
| CLI | nested dispatch | UNVERIFIED | No CLI nested dispatch result captured | 2026-08-03 |
| CLI | result retrieval | UNVERIFIED | No CLI result retrieval payload captured | 2026-08-03 |
| CLI | candidate binding | UNVERIFIED | No CLI final-candidate snapshot captured | 2026-08-03 |
| codex exec | Agent selection | VERIFIED | Parent launch records and child paths `sol_native_identity` / `luna_native_identity` | 2026-08-05 |
| codex exec | exact model | VERIFIED | Child contexts: `gpt-5.6-sol` and `gpt-5.6-luna` | 2026-08-05 |
| codex exec | reasoning | VERIFIED | Child contexts: Sol `high`, Luna `max` | 2026-08-05 |
| codex exec | nested dispatch | VERIFIED | Agent path `/root/sol_native_identity/luna_native_identity` | 2026-08-05 |
| codex exec | result retrieval | VERIFIED | Luna structured `PASS`; Sol final `PASS` | 2026-08-05 |
| codex exec | candidate binding | UNVERIFIED | Read-only arithmetic acceptance had no changed-file candidate | 2026-08-05 |

The v0.5 Desktop proof deliberately does not ask the child to self-report.
Exact selection comes from the authoritative Host/tool role mapping plus the
parent launch record. The child handshake reports actual technical capability,
operational authorization, and zero side effects. This runtime exposed broader filesystem
capability than the configured ceilings; every audit therefore kept
`write_scope: []` and used Host-owned before/after candidate hashes. Capability
did not silently widen authorization.

The renamed `$sol-control` fresh-session and Native Nested checks were captured
after the v0.4 global installation. The persistent `codex exec` runtime records
prove the Sol-to-Luna path, exact child models and efforts, inherited read-only
boundary, structured Luna result, and Sol review. Its candidate binding remains
`UNVERIFIED` because that acceptance case intentionally changed no file.

The v0.5 matched CLI smoke is recorded separately in
[`tests/v050-live-smoke.md`](../../tests/v050-live-smoke.md). It measures one
planning-only baseline/candidate pair and does not replace the full benchmark.
