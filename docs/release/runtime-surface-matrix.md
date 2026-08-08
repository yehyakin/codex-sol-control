# Runtime surface matrix

Release-time documentation for Sol Control. This matrix is not a
per-task checklist and does not turn configuration text into runtime proof.
Statuses are limited to `VERIFIED`, `FAILED`, and `UNVERIFIED`.

Date: 2026-08-08

| Surface | Signal | Status | Evidence location | Date |
| --- | --- | --- | --- | --- |
| Desktop | Agent selection | VERIFIED | Host launch record selected `sol-controller` with `fork_turns="none"`; child session metadata recorded the same role | 2026-08-08 |
| Desktop | exact model | VERIFIED | Authoritative Host/tool mapping fixed `sol-controller` to `gpt-5.6-sol` | 2026-08-08 |
| Desktop | reasoning | VERIFIED | Authoritative Host/tool mapping fixed Sol reasoning effort to `high` | 2026-08-08 |
| Desktop | nested dispatch | UNVERIFIED | This acceptance run launched and reviewed with Sol but did not launch a Desktop worker | 2026-08-08 |
| Desktop | result retrieval | VERIFIED | The same Sol returned handshake `PASS` and final review `PASS` | 2026-08-08 |
| Desktop | candidate binding | VERIFIED | Sol reviewed the six-path final diff bound to SHA-256 `bb6c52df3293585112160790df6109a726309ce4f62fe1ee5ba269403ac2abe9` | 2026-08-08 |
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

The v0.4.1 Desktop proof deliberately does not ask the child to self-report
model or reasoning metadata that its runtime surface cannot observe. Exact
selection comes from the authoritative Host/tool role mapping plus the parent
launch record; the child handshake proves permissions, operational constraints,
and zero side effects. Desktop worker nesting remains `UNVERIFIED`.

The renamed `$sol-control` fresh-session and Native Nested checks were captured
after the v0.4 global installation. The persistent `codex exec` runtime records
prove the Sol-to-Luna path, exact child models and efforts, inherited read-only
boundary, structured Luna result, and Sol review. Its candidate binding remains
`UNVERIFIED` because that acceptance case intentionally changed no file.
