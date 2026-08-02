# v0.4 Forward Tests

Date: 2026-08-03

Scope: routing-contract fixtures plus isolated installer roots. No business
repository, global agent file, or live production system is read or modified.

## Method

- The fourteen scenarios are defined in `tests/fixtures/forward-cases.json`.
- Each case describes the expected route without exposing internal runtime
  mechanics as a public mode or fixed worker-count promise.
- Contract tests check explicit invocation, direct handling of ordinary simple
  work, Sol-only planning, complete Luna packets/results, ownership, dynamic
  live-capacity batching, exact selection proof, and focused review fixes.
- Four reliability cases add final-candidate evidence binding, transport/spawn
  completion separation, no-delta retry blocking, and long-task-only resume.
- Installer tests use a temporary `ORCHESTRATE_HOME`, synthesize a v0.1
  installation with checksums, and exercise migration, modified-target
  preservation, rollback, uninstall, restore, unrelated files, and
  `config.toml` integrity.

## Scenario matrix

| Case | Expected route | Luna expectation | Review expectation |
| --- | --- | --- | --- |
| Ordinary simple work | `direct` | none | not applicable |
| Explicit `$sol-luna` execution | `sol_then_luna` | required | PASS |
| Plan-only request | `sol` | optional, including zero | not applicable |
| Single-file execution | `sol_then_luna` | required | PASS |
| Changing live capacity | `sol_then_luna` | required, dynamically batched | PASS |
| Shared integration file | `sol_then_luna` | one owner for the shared file | PASS |
| Incomplete Luna packet | `sol_then_luna` | BLOCKED before write | BLOCKED |
| Unprovable exact selection | `blocked` | BLOCKED | BLOCKED |
| One missed criterion | `sol_then_luna` | one focused fix at most | FIX |
| Dirty worktree | `sol_then_luna` | scoped writes only | PASS |
| Stale evidence after candidate change | `sol_then_luna` | BLOCKED until affected verification reruns | BLOCKED |
| Transport/spawn `completed` | `sol_then_luna` | delivery only; structured result required | BLOCKED |
| Identical retry with no Delta | `sol_then_luna` | no relaunch without new evidence | BLOCKED |
| Long-task resume | `sol_then_luna` | minimal resume packet required | PASS |

## Reliability guard status

The v0.4 focused contract, README, and benchmark suite now runs 41 tests with
zero failures or errors. The full repository test entrypoint runs 62 tests and
also passes. The anonymous pre-implementation RED evidence is retained in
`tests/fixtures/v040-baseline-red.md`.

No public runtime-mode enumeration or fixed worker-count taxonomy is part of
this forward contract.
