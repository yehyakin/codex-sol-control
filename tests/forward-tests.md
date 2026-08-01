# Forward Tests

Date: 2026-08-01

Scope: simulated prompts and temporary test roots only. No business repository or production system was read or modified.

## Method

- The 13 cases are defined in `tests/fixtures/forward-cases.json`.
- A fresh read-only `gpt-5.6-sol` agent with `high` reasoning read the actual Skill, routing protocol, agent TOMLs, fixture, and contract tests.
- Each case was classified independently against the repository contract. The evaluator returned level, mode, delegation count, concrete assertions, and source-line evidence.
- Static and installer behavior was separately verified by the Python test suite. Real model execution is covered in the implementation report rather than mixed into the Skill runtime context.

## Results

| Case | Actual route | Delegation | Result | Key evidence |
| --- | --- | ---: | --- | --- |
| Simple button copy | Level 0 / Direct | 0 | PASS | No Sol or Luna; Main verifies the narrow diff. |
| Coupled architecture analysis | Level 1 / Sol Assist | 1 | PASS | One read-only Sol; no forced Luna. |
| Three independent module audits | Level 2 / Sol to Luna | 3 | PASS | One graph, one parallel frontier, disjoint scopes. |
| Same-file proposals | Level 2 / Sol to Luna | 2 | PASS | Parallel read-only proposals; one exclusive writer. |
| Database to API to frontend | Level 3 / High-Risk | 3 | PASS | Dependency waves, authorization, recovery checkpoint. |
| Luna PASS without evidence | Level 2 / Correction | 1 | PASS | PASS rejected; one narrow Correction Packet. |
| Luna timeout | Level 2 / Bounded Retry | 1 | PASS | Failure recorded; repaired packet; at most one retry. |
| Conflicting Luna results | Level 2 / Sol Arbitration | 1 | PASS | No mechanical merge; evidence-based arbitration. |
| Omitted original requirement | Level 2 / Sol Final Review | 1 | PASS | Coverage review returns FAIL and a narrow fix. |
| Required model unavailable | Level 2 / Fail Closed | 0 | PASS | No spoofing or silent substitution. |
| Native Nested | Level 2 / Fail Closed | 0 | BLOCKED | Depth >=2 and exact nested Luna model/effort were not live-proved. |
| Compatibility | Level 2 / Compatibility | 2 | PASS | Main launches Sol, Luna, then Sol review with the same packet. |
| Dirty worktree | Level 2 / Protected Write | 1 | PASS | User changes preserved; exclusive scope and final diff review. |

Summary: 12 scenario assertions passed. Native Nested was deliberately not claimed: the current runtime did not expose sufficient live evidence for nested custom-agent selection, effective depth, exact nested model/effort, and inherited permission boundary. This is a correct fail-closed result, not a silent downgrade. Compatibility remains eligible for the live route test.

## RED baseline

Before the target Skill existed, four independent pressure prompts already avoided unsafe shortcuts, but they did not reliably produce the canonical execution graph, Luna packet/return, Correction Packet, and Sol final-review schemas. Those structural omissions established the RED baseline recorded in `tests/fixtures/baseline-red.md`.
