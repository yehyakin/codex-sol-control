# Runtime surface matrix

Release-time documentation for Sol Control. This matrix is not a
per-task checklist and does not turn configuration text into runtime proof.
Statuses are limited to `VERIFIED`, `FAILED`, and `UNVERIFIED`.

Date: 2026-08-05

| Surface | Signal | Status | Evidence location | Date |
| --- | --- | --- | --- | --- |
| Desktop | Agent selection | UNVERIFIED | No runtime identity payload captured in this release | 2026-08-03 |
| Desktop | exact model | UNVERIFIED | Configuration names are not runtime proof | 2026-08-03 |
| Desktop | reasoning | UNVERIFIED | No runtime reasoning-effort payload captured | 2026-08-03 |
| Desktop | nested dispatch | UNVERIFIED | Nested launch capability was not independently proved | 2026-08-03 |
| Desktop | result retrieval | UNVERIFIED | No checkable runtime artifact or path was captured for the observed handoff | 2026-08-03 |
| Desktop | candidate binding | UNVERIFIED | Contract rule exists; no runtime candidate snapshot was captured | 2026-08-03 |
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

The renamed `$sol-control` fresh-session and Native Nested checks were captured
after the v0.4 global installation. The persistent `codex exec` runtime records
prove the Sol-to-Luna path, exact child models and efforts, inherited read-only
boundary, structured Luna result, and Sol review. Candidate binding remains
`UNVERIFIED` because this acceptance case intentionally changed no file.
