# Tiered-routing Forward Tests

Date: 2026-08-20

Scope: routing-contract fixtures plus isolated installer roots. No business
repository, global agent file, or live production system is read or modified.

## Method

- The thirty-nine scenarios are defined in `tests/fixtures/forward-cases.json`.
- Each case describes the expected route without exposing internal runtime
  mechanics as a public mode or fixed worker-count promise.
- Contract tests check explicit invocation, direct handling of ordinary simple
  work, Controller-only planning, complete efficient-worker packets/results,
  ownership, dynamic live-capacity batching, exact selection proof, and focused
  review fixes.
- Tiered-routing cases pin the efficient profile to clear, low-ambiguity,
  falsifiable small-context work; route the complex profile to cross-module,
  long-context, ambiguous-debugging, shared-interface, and high-risk work; and
  keep the Controller as the only controller and final reviewer.
- Four reliability cases add final-candidate evidence binding, transport/spawn
  completion separation, no-delta retry blocking, and long-task-only resume.
- Seven continuity cases add authorized-plan continuation, status-inquiry
  continuity, planning convergence, partial-stage delivery, one-time
  result-only recovery after transport completion, safe blocking after failed
  recovery, and urgency-invariant evidence thresholds.
- One steering case ensures explicit user cancellation, replacement, or
  redirection stops the old plan and triggers re-planning, while ordinary status
  inquiries still continue the authorized work.
- Ownership-transfer cases distinguish the only allowed upgrade from the
  forbidden handoff: only when the efficient worker's first failure happens
  before it writes any owned file may the Controller forward the same task and
  unchanged scope to the complex profile once. After any owned write, the
  efficient worker retains ownership; only that original owner may receive one
  focused fix, otherwise return `BLOCKED`. The complex worker's write state is
  never the escalation gate.
- Eight evidence-first cases cover stable Requirement IDs, artifact-first Controller
  review, wrong-scope verifier rejection, high-risk selective challenge,
  zero-challenge standard work, idempotent resume, timeout-after-write
  ownership, and residual suggestions outside the closed verdict.
- Two runtime-boundary cases distinguish technical capability from task
  authorization: reversible workspace work may continue with narrow scope and
  Host-owned snapshots, while destructive or irreversible external work still
  fails closed without an enforceable boundary or explicit broader approval.
- Installer tests use a temporary `ORCHESTRATE_HOME`, synthesize a v0.5
  installation with checksums, and exercise migration, modified-target
  preservation, rollback, uninstall, restore, unrelated files, and
  `config.toml` integrity. All three v1 capability-role targets are covered by
  ownership state and checksums, including exact uninstall and restore behavior.

## Scenario matrix

| Case | Expected route | Worker expectation | Review expectation |
| --- | --- | --- | --- |
| Ordinary simple work | `direct` | none | not applicable |
| Explicit `$codex-prove` execution | `controller_then_efficient` | required | PASS |
| Plan-only request | `controller` | optional, including zero | not applicable |
| Single-file execution | `controller_then_efficient` | required | PASS |
| Changing live capacity | `controller_then_efficient` | required, dynamically batched | PASS |
| Shared integration file | `controller_then_efficient` | one owner for the shared file | PASS |
| Incomplete efficient-worker packet | `controller_then_efficient` | BLOCKED before write | BLOCKED |
| Unprovable exact selection | `blocked` | BLOCKED | BLOCKED |
| One missed criterion | `controller_then_efficient` | one focused fix at most | FIX |
| Dirty worktree | `controller_then_efficient` | scoped writes only | PASS |
| Stale evidence after candidate change | `controller_then_efficient` | BLOCKED until affected verification reruns | BLOCKED |
| Transport/spawn `completed` | `controller_then_efficient` | delivery only; structured result required | BLOCKED |
| Identical retry with no Delta | `controller_then_efficient` | no relaunch without new evidence | BLOCKED |
| Long-task resume | `controller_then_efficient` | minimal resume packet required | PASS |
| Authorized plan is not a stop point | `controller_then_efficient` | execution continues unless a real gate appears | PASS |
| Status inquiry during authorized work | `controller_then_efficient` | no pause or new permission required | PASS |
| Planning timebox convergence | `controller` | plan, determination, or evidence gap | not applicable |
| Later-stage blocker with earlier evidence | `controller_then_efficient` | completed earlier stage is delivered | BLOCKED |
| Completed without structured result | `controller_then_efficient` | one same-worker result-only recovery | PASS |
| Recovery still has no bound result | `controller_then_efficient` | no second recovery or re-execution | BLOCKED |
| Urgency does not lower evidence | `blocked` | safety threshold unchanged | BLOCKED |
| Explicit user steering | `controller` | old plan stops and the Controller re-plans | not applicable |
| Efficient: low-ambiguity, falsifiable, small context | `controller_then_efficient` | required; complex worker not selected | PASS |
| Complex: cross-module and long context | `controller_then_complex` | no efficient worker; complex worker required | PASS |
| Model identity unavailable | `blocked` | efficient and complex workers BLOCKED; no substitution | BLOCKED |
| Runtime capability broader than a read-only audit | `controller_then_efficient` | empty write scope plus Host-owned before/after snapshot | PASS |
| Irreversible work without an enforceable boundary | `blocked` | no worker execution or external side effect | BLOCKED |
| Efficient worker first classification failure before any write | `controller_then_complex` | same task/scope upgraded once only after zero efficient-worker-owned writes | PASS |
| Efficient worker first failure after an owned write | `controller_then_efficient` | efficient worker retains scope; one focused fix or `BLOCKED`; complex worker blocked | FIX/BLOCKED |
| Shared file unique owner with complex route | `controller_then_complex` | exact write scope; one owner | PASS |
| Missing Requirement evidence | `controller_then_efficient` | REQ gap remains visible | FIX |
| Worker PASS treated as a claim | `controller_then_efficient` | artifact-first evidence review | PASS |
| Verifier targets the wrong scope | `controller_then_efficient` | `evidence_quality` failure | FIX |
| High-risk selective challenge | `controller_then_complex` | one read-only challenge at most | PASS |
| Standard task | `controller_then_efficient` | zero challenge calls | PASS |
| Resume after interruption | `controller_then_efficient` | no duplicate dispatch or attempt reset | PASS |
| Timeout after an owned write | `controller_then_efficient` | efficient worker retains ownership; complex worker blocked | BLOCKED |
| Residual suggestion after full coverage | `controller_then_efficient` | suggestion remains non-gating | PASS |

## Reliability guard status

The ownership-transfer tests preserve a pre-fix RED proof and a post-fix GREEN
regression: the allowed case has zero efficient-worker-owned writes before the first
failure, while the forbidden case has at least one write and keeps ownership
with the efficient worker. Syntax and environment failures are not an acceptable substitute.
The earlier v0.4 RED evidence remains in `tests/fixtures/v040-baseline-red.md`.

No public runtime-mode enumeration or fixed worker-count taxonomy is part of
this forward contract.
