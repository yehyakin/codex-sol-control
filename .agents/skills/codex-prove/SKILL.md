---
name: codex-prove
description: Use only when the user explicitly invokes $codex-prove to plan, route, execute, verify, and evidence-gate a complex, multi-part, parallelizable, or high-consequence Codex task.
---

# Codex PROVE

Use one controller to plan and review. Route bounded execution to the smallest
capable worker profile. Deliver only after real artifacts and falsifiable
evidence satisfy every requirement.

PROVE means **Planning, Routing, Ownership, Verification, Evidence**. It is an
evidence-bound workflow, not a guarantee of perfect correctness.

An explicit invocation always starts with the controller. Planning-only work may
use zero workers. Do not invoke this Skill implicitly; ordinary small work stays
Direct.

## Language

默认使用中文编写计划、任务包、状态更新、worker 结果和最终审核。用户明确要求其他
语言时使用用户指定的语言。代码、命令、路径、标识符和原始证据按需保留原文。

## Load the protocol

Before planning or dispatch, read [references/orchestration.md](references/orchestration.md).
When selecting custom agents, proving runtime capability, choosing Native Nested
or Compatibility mode, or handling a model/profile failure, also read
[references/runtime-notes.md](references/runtime-notes.md).

## Roles

- **Controller:** understand the goal, assign stable Requirement IDs, choose the
  execution graph, own scheduling and file ownership, and perform the sole final
  review. Remain operationally read-only and avoid bulk implementation.
- **Complex worker:** execute one bounded task that needs long context,
  cross-module judgment, ambiguous debugging, a shared interface decision, or
  high-consequence implementation.
- **Efficient worker:** execute one bounded, clear, low-ambiguity, falsifiable,
  small-context, mechanical, or high-throughput task.

These are capability roles, not permanent model brands. The checked-in TOML
files define the current default model and reasoning effort for each role. Never
silently substitute a model, profile, reasoning effort, permission boundary, or
agent type.

The controller is the only controller and sole final reviewer for a run.

## Runtime proof and fail-closed gate

Start every custom agent with `fork_turns="none"`. Use its first turn only for an
identity and capability handshake. Prove the selected `agent_type`, model,
reasoning effort, and fork mode from the authoritative Host/tool role mapping
plus the parent launch record. Do not require the child to self-report identity
fields its runtime cannot observe.

During the handshake, the child reports only its effective technical capability,
operational constraint, and that it performed no task, repository write, or
subagent launch. Send the complete task packet only after the proof matches the
configuration. A label or TOML file alone is not runtime proof.

Keep capability separate from authorization. Broader technical access does not
widen the user-approved task. For reversible workspace work, record the mismatch
and use Host-owned before/after changed-path checks. For destructive,
credential-bearing, production, privacy-sensitive, or irreversible work, require
an enforceable matching boundary or explicit broader authorization. If the
selected agent, model, reasoning effort, fork mode, or required scope/no-write
evidence cannot be proved, return `BLOCKED`; do not impersonate the requested
profile. This is the **Fail Closed** rule.

## Plan

Produce the smallest useful graph:

```yaml
goal: "The user's final outcome"
done_when:
  - id: REQ-1
    criterion: "Observable completion criterion"
    evidence: "Required evidence"
tasks:
  - id: task-a
    task: "One bounded action"
    requirements: [REQ-1]
    agent_profile: efficient | complex
    dependencies: []
    read_scope: ["needed/path"]
    write_scope: ["owned/path"]
    do_not_touch: ["all other paths"]
    expected_result: "Observable result"
    verification: "Exact procedure and passing condition"
    required_evidence: "Evidence bound to the final candidate"
    can_launch: true
    held_reason: null
stages:
  - [task-a]
integration_owner: host
```

Give every requirement evidence and at least one owning task. Give every writable
file exactly one owner for the entire run. Use the minimum sufficient number of
workers. A stage may launch only as many ready tasks as live capacity permits;
queue the rest. Do not promise a fixed worker maximum.

## Task packet

Send one complete, minimal packet to each worker. `Context` is optional; every
other field is required.

```text
Task ID: <stable task id>
Task: <one bounded task>
Requirement IDs: <REQ-1, REQ-2>
Context: <optional task-local input>
Read scope: <exact readable paths>
Write scope: <exact writable paths>
Do not touch: <excluded paths and side effects>
Dependencies: <completed prerequisite task IDs or None>
Expected result: <observable acceptance condition>
Verification:
  Procedure: <exact command or procedure>
  Passing condition: <falsifiable passing condition>
Required evidence: <diff, output, artifact, or observation bound to the final candidate>
Stop conditions: <conditions that require BLOCKED>
```

An incomplete, contradictory, or unauthorized packet is `BLOCKED`. Workers do
not infer missing scope, redesign the plan, approve the overall task, or create
subagents.

## Worker result

```text
Task ID: <task id>
Status: PASS | BLOCKED
Summary: <what happened>
Inspected: <exact files>
Changed: <exact files, or None>
Requirement coverage: <each assigned REQ-ID and its evidence>
Verification: <commands or procedures and exact results>
Evidence: <diff, test, build, log, screenshot, or artifact evidence>
Assumptions: <explicit assumptions or None>
Risks: <remaining risks or None>
Failure class: runtime | timeout | model_identity | permission | dependency | scope | verification | evidence_quality | conflict | none
Blocker: <None or the concrete blocker>
```

Transport or spawn `completed` proves delivery lifecycle completion only. If it
arrives without a structured result, allow exactly one result-only follow-up to
the same worker, with no new write or re-execution authority. If the result is
still unavailable or unbound to the final candidate, return `BLOCKED`.

## Ownership and scheduling

- Run independent, disjoint tasks in the same stage.
- Run dependent, overlapping, shared-config, or uncertain tasks sequentially.
- Allow multiple read-only analyses of one file, then assign one write owner.
- Preserve unrelated user changes and compare actual changed paths with every
  task scope before integration.
- Never transfer a file after its owner has written it. If an efficient worker's
  first failure occurs before any owned write, the controller may escalate the
  unchanged task and scope once to the complex profile. Otherwise the original
  owner gets at most one focused fix or the task becomes `BLOCKED`.

## Verification and review

Define the minimum falsifiable verification before dispatch. File existence,
"looks correct," a worker summary, or an exit code disconnected from the
requirement is not enough. Evidence must bind to the final candidate through a
commit plus diff identity or an exact changed-file snapshot. If the candidate
changes, rerun affected checks.

The controller reviews in this order:

1. Original request and `done_when`.
2. Repository baseline and actual changed paths.
3. Real files and complete diff.
4. Verification output and artifacts.
5. Requirement coverage.
6. Worker summaries and self-assessments.

Verify the verifier: confirm the procedure exercised the intended requirement on
the correct final candidate, at the right scope, with the stated passing
condition. Treat wrong-scope, tautological, existence-only, skipped, unexpected
test/lockfile-mutating, or candidate-unbound checks as `evidence_quality`
failures.

Use only this final verdict vocabulary:

```yaml
verdict: PASS | FIX | BLOCKED
requirements_coverage:
  - requirement: REQ-1
    status: satisfied | unsatisfied | blocked
    evidence: "Exact file, diff, command output, or artifact"
findings: []
required_fixes: []
residual_suggestions: []
evidence_quality: sufficient | insufficient
remaining_risks: []
```

`PASS` requires every Requirement ID to be satisfied and evidenced. Keep optional
improvements separate. A worker `PASS` is an untrusted claim, never final proof.

## Challenge, correction, and continuity

Use zero challenge calls for ordinary low-risk tasks. For high-consequence,
cross-module/shared-interface, destructive or security-sensitive work, ambiguous
root cause, conflicting evidence, or an unresolved Requirement ID, the controller
may add at most one bounded read-only challenge with `write_scope: []`. It
returns findings and evidence only and cannot become a second reviewer.

Issue at most one focused Correction Packet to the original owner without
expanding scope. Keep the same scope. Include a non-`none` Failure class and a concrete same-scope
Delta or new evidence. Never relaunch an identical packet without new evidence.

For an authorized run, a plan is not a stop point. Continue through approved
stages unless there is a new permission request, irreversible choice, real
blocker, explicit cancellation, replacement, or redirection. A normal status
question does not pause work. User urgency never lowers the evidence threshold.
Set a bounded planning timebox appropriate to the task; when it expires, the
controller must return the smallest executable graph, a concrete decision, or
the precise evidence gap instead of continuing open-ended analysis. If a later
stage becomes blocked, still deliver any earlier stage whose requirements and
final-candidate evidence are complete, clearly separated from the blocker.

Use a resume packet only for long, interrupted, or context-compressed work. Store
`run_id`, `goal`, `completed`, `in_flight`, `ownership`,
`requirement_coverage`, `candidate_identity`, `attempts`, `artifact_location`,
and `next_action`. Never redispatch completed tasks or reset attempts.
