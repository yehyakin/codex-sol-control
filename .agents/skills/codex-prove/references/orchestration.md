# Codex PROVE orchestration contract

This reference is the normative execution contract. The controller owns every
planning, routing, scheduling, ownership, correction, and completion decision.
Workers own only their bounded task packets.

## Contents

1. Entry and invariants
2. Requirement graph
3. Routing and stages
4. Ownership
5. Task and result contracts
6. Verification and evidence
7. Review and correction
8. Failure handling
9. Continuity

## 1. Entry and invariants

- Enter only through an explicit `$codex-prove` invocation or the temporary
  explicit `$sol-control` compatibility entry.
- Start with exactly one controller. Do not create a standing team or a second
  controller.
- Allow zero workers for planning-only or review-only work.
- Keep ordinary small work Direct when the Skill was not explicitly invoked.
- Use capability roles rather than model brands in plans and task packets.
- Launch with `fork_turns="none"`, then prove the selected agent, model,
  reasoning effort, fork mode, and effective boundary before sending any plan
  or task. Use an identity-only handshake with no planning, execution, write, or
  subagent activity.
- Preserve the Host as authorization, workspace-safety, integration, and final
  user-communication owner.

PROVE is an evidence gate. It reduces unsupported completion claims; it cannot
guarantee perfect correctness.

## 2. Requirement graph

The controller returns this top-level shape:

```yaml
goal: "Concrete outcome"
done_when:
  - id: REQ-1
    criterion: "Observable criterion"
    evidence: "Required evidence"
tasks:
  - id: task-a
    task: "One bounded action"
    requirements: [REQ-1]
    agent_profile: efficient | complex
    dependencies: []
    read_scope: ["exact/read/path"]
    write_scope: ["exact/write/path"]
    do_not_touch: ["excluded/path or side effect"]
    expected_result: "Observable result"
    verification: "Exact procedure and passing condition"
    required_evidence: "Evidence bound to the final candidate"
    can_launch: true
    held_reason: null
stages:
  - [task-a, task-b]
  - [task-c]
integration_owner: host
```

Every `done_when` item has a stable `REQ-*` ID. Every task maps to at least one
Requirement ID, and every Requirement ID has at least one owning task or an
explicit Host-owned integration check. Reject vague criteria, unowned
requirements, tasks with no acceptance evidence, and stages that violate a
dependency or ownership edge.

The controller states the smallest complete graph. It does not split work by
file merely to increase agent count.

## 3. Routing and stages

Choose the **efficient** profile only for clear, low-ambiguity, falsifiable,
small-context, mechanical, or high-throughput work. Choose the **complex**
profile for cross-module work, long-context investigation, ambiguous debugging,
shared-interface judgment, or high-consequence implementation.

Tasks in one stage may run concurrently only when:

- all dependencies are satisfied;
- their write scopes are disjoint;
- they do not mutate the same component, generated output, lockfile, shared
  configuration, migration state, or external resource;
- their combined launch count fits current live capacity.

Queue excess ready tasks for the next batch. If dependency order, generated
effects, or write overlap is uncertain, run sequentially. Later stages wait for
required earlier evidence.

Use the minimum sufficient parallelism. One to three workers is the normal
range, not a hard cap. Never promise a fixed maximum because live capacity is a
runtime property.

## 4. Ownership

Assign each writable file, component, shared interface, migration, generated
artifact, and external side effect to one owner for the entire run. Multiple
workers may read the same file. Alternative proposals may be gathered
read-only, but one selected owner performs the write.

Before dispatch, reject overlapping or ambiguous write scopes. Before
integration, compare the Host-owned baseline with actual changed paths and each
packet. Preserve unrelated user changes.

Never transfer an owned file after its worker writes it. The controller may
escalate an efficient-profile task once to the complex profile only when the
first failure occurred before any owned write and the task, requirements, and
scope remain unchanged. After a write, only the original owner may receive one
focused correction; otherwise return `BLOCKED`.

## 5. Task and result contracts

### Worker task

```text
Task ID: <stable task id>
Task: <one bounded action>
Requirement IDs: <REQ-1, REQ-2>
Context: <optional minimal task-local input>
Read scope: <exact readable paths>
Write scope: <exact writable paths or []>
Do not touch: <excluded paths and side effects>
Dependencies: <completed prerequisite IDs or None>
Expected result: <observable acceptance condition>
Verification:
  Procedure: <exact command or procedure>
  Passing condition: <falsifiable passing condition>
Required evidence: <diff, output, artifact, or observation>
Stop conditions: <conditions requiring BLOCKED>
```

`Context` is optional; all other fields are required. The identity-only
handshake is the sole exception. A worker receiving an incomplete,
contradictory, unauthorized, or dependency-incomplete packet returns `BLOCKED`
without guessing.

### Worker result

```text
Task ID: <task id>
Status: PASS | BLOCKED
Summary: <what happened>
Inspected: <exact files>
Changed: <exact files, or None>
Requirement coverage: <each assigned REQ-ID and exact evidence>
Verification: <procedures and exact results>
Evidence: <diff, test, build, log, screenshot, or artifact>
Assumptions: <explicit assumptions or None>
Risks: <remaining risks or None>
Failure class: runtime | timeout | model_identity | permission | dependency | scope | verification | evidence_quality | conflict | none
Blocker: <None or concrete blocker>
```

A worker approves only its task. `completed`, a prose summary, or an agent label
is not a task `PASS`.

If transport reports `completed` without the structured result, allow exactly
one result-only follow-up to that same worker. It authorizes no new write or
re-execution. A second missing or candidate-unbound result is `BLOCKED`.

## 6. Verification and evidence

The controller defines the minimum falsifiable verification before dispatch.
The worker may add stronger checks but cannot lower the gate.

Examples:

- Code: exact test/build command, expected scope, exit code, and affected tests.
- Configuration: load with the real parser and assert required fields.
- UI: start the runnable product, complete the named path, inspect console and
  visual output, and capture evidence when needed.
- Documentation/design: render or open the final artifact and inspect required
  content and layout.
- Research: cite primary sources, separate fact from inference, and map findings
  to every Requirement ID.

Evidence must bind to the final candidate through a commit plus complete diff or
an exact changed-file snapshot. If the candidate changes, affected evidence is
stale. File existence, successful transport, a disconnected exit code,
"looks correct," or a worker's confidence is not evidence.

The controller verifies the verifier: the check must target the correct final
candidate, exercise the intended requirement, use the expected scope, retain a
falsifiable passing condition, and produce the required artifact. Wrong-module,
tautological, existence-only, skipped, unexpected test/lockfile-mutating, or
candidate-unbound checks fail under `evidence_quality`.

## 7. Review and correction

Review artifact-first:

1. Original request and `done_when`.
2. Baseline, dirty-worktree state, and actual changed paths.
3. Real files and complete diff.
4. Verification output and artifacts.
5. Requirement coverage.
6. Worker summaries and self-assessments.

Return:

```yaml
verdict: PASS | FIX | BLOCKED
requirements_coverage:
  - requirement: REQ-1
    status: satisfied | unsatisfied | blocked
    evidence: "Exact file, diff, output, or artifact"
findings: []
required_fixes: []
residual_suggestions: []
evidence_quality: sufficient | insufficient
remaining_risks: []
```

`PASS` requires every Requirement ID to be satisfied and evidenced, no
out-of-scope write, and verification bound to the final candidate. Optional
improvements remain residual and do not change a valid `PASS`. Any unsatisfied
Requirement ID is gating work, not a suggestion.

Issue at most one focused Correction Packet to the original owner. Keep the same
scope and include:

```text
Failure class: <non-none allowed class>
Finding: <specific failed requirement or evidence defect>
Delta: <changed instruction, narrowed action, or new evidence>
Verification: <unchanged or stronger falsifiable gate>
```

Do not relaunch an identical packet without new evidence. Do not use a failed
task as permission for broader refactoring.

## 8. Failure handling

Classify a failure before retrying:

- `model_identity`: requested profile cannot be proved; fail closed.
- `permission`: effective boundary cannot safely support the authorized action.
- `scope`: changed path or side effect exceeded the packet.
- `verification` or `evidence_quality`: result lacks falsifiable proof.
- `dependency`: prerequisite or environment is unavailable.
- `conflict`: worker results or ownership claims disagree.
- `runtime` or `timeout`: transport/runtime failed.

First inspect whether the packet was ambiguous. Repair the packet when that is
the cause, then allow at most one narrow retry/fix under the ownership rules.
Escalate conflicting results to the controller for arbitration; never
mechanically merge summaries or let a worker approve itself.

## 9. Continuity

After authorization, a plan is not a stop point. Continue through approved
stages unless a new permission request, irreversible choice, real blocker,
explicit cancellation, replacement, or redirection appears. A status inquiry
does not pause work. User urgency does not lower the verification gate.

The Host sets a bounded planning timebox proportional to task risk and size.
When it expires, the controller returns the smallest executable graph, a
concrete decision, or the exact missing evidence; it does not continue
open-ended analysis. If a later stage becomes blocked, deliver any earlier
stage whose Requirement IDs and final-candidate evidence are complete, and
label the remaining blocker without upgrading partial evidence into overall
`PASS`.

For long, interrupted, or context-compressed runs only, persist:

```yaml
run_id: "stable id"
goal: "current goal"
completed: []
in_flight: []
ownership: {}
requirement_coverage: {}
candidate_identity: "commit+diff or snapshot"
attempts: {}
artifact_location: "path or record"
next_action: "one concrete action"
```

On resume, rebuild state from real artifacts, do not redispatch completed tasks,
do not reset attempts, and re-plan or return `BLOCKED` on candidate mismatch.
