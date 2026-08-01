# v0.2.0 Forward Tests

Date: 2026-08-01

Scope: routing-contract fixtures plus isolated installer roots. No business
repository, global agent file, or live production system is read or modified.

## Method

- The ten scenarios are defined in `tests/fixtures/forward-cases.json`.
- Each case describes the expected route without exposing internal runtime
  mechanics as a public mode or fixed worker-count promise.
- Contract tests check explicit invocation, direct handling of ordinary simple
  work, Sol-only planning, complete Luna packets/results, ownership, dynamic
  live-capacity batching, exact selection proof, and focused review fixes.
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

## RED status

Against the current v0.1 production files, the updated suite exited non-zero:
21 tests ran with 14 assertion failures and 0 errors. The failures identify
the missing new skill, Sol controller, simplified routing contract, and
v0.1-to-v0.2 installer migration; they are not import, parsing, or
temporary-root setup errors.

No public runtime-mode enumeration or fixed worker-count taxonomy is part of
this forward contract.
