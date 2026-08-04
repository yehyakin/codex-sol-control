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
| codex exec | Agent selection | UNVERIFIED | No codex exec runtime identity payload captured | 2026-08-03 |
| codex exec | exact model | UNVERIFIED | Configuration names are not runtime proof | 2026-08-03 |
| codex exec | reasoning | UNVERIFIED | No codex exec reasoning-effort payload captured | 2026-08-03 |
| codex exec | nested dispatch | UNVERIFIED | No codex exec nested dispatch result captured | 2026-08-03 |
| codex exec | result retrieval | UNVERIFIED | No codex exec result retrieval payload captured | 2026-08-03 |
| codex exec | candidate binding | UNVERIFIED | No codex exec final-candidate snapshot captured | 2026-08-03 |

The Compatibility workflow shape was exercised in the earlier release, but the
individual identity rows remain `UNVERIFIED` because no checkable runtime
identity payload was captured. The renamed `$sol-control` fresh-session check is
recorded separately after v0.4 installation. Agent selection, exact model,
reasoning effort, nested dispatch, result retrieval, and candidate binding stay
`UNVERIFIED` until a runtime payload and its evidence location are available.
