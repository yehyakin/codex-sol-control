---
name: sol-control
description: Use when the user explicitly invokes $sol-control for Sol-controlled, cost-aware execution of a complex, multi-part, parallelizable, or high-consequence task.
---

# Sol Control

Sol is the single controller. One or more selected workers execute bounded tasks,
verify their results, and return evidence for Sol to review.

Ordinary simple work stays direct unless the user explicitly invokes
`$sol-control`. An explicit invocation always starts with Sol. Planning-only work may use zero workers (and therefore zero Luna workers).

## Language

默认使用中文编写 Sol 计划、worker 任务与结果、状态更新和最终审核。用户明确要求
其他语言时，使用用户指定的语言。代码、命令、路径、标识符和原始证据可按需保留
原文。

## Roles

- **Sol:** understand the real goal, give every completion criterion a stable
  Requirement ID, split work, assign file ownership, schedule stages, and
  perform the artifact-first final review. Sol is read-only and does not
  perform bulk implementation.
- **Luna Max:** execute exactly one assigned task, modify only its write scope,
  run the required verification, and return evidence. Luna does not redesign
  the plan, broaden scope, create subagents, or approve the overall task.
- **Terra High:** execute exactly one assigned complex task under the same
  packet, scope, evidence, and authorization rules as Luna. Terra does not
  plan, schedule, create subagents, or approve the overall task.

## Tiered execution routing

Sol is the **only controller** and final reviewer. This is a routing rule, not
a permanent agent team.

- Route to **Luna Max** only when the work is clear, low-ambiguity,
  falsifiable, small context, mechanical, or high-throughput.
- Route to **Terra High** for cross-module work, long-context investigation,
  ambiguous debugging, shared interface judgment, or high-risk implementation.
- Start every custom agent with a fresh context: set `fork_turns="none"` and use
  the first turn only as an identity handshake. The authoritative Host/tool
  contract plus the parent launch record must prove the selected `agent_type`,
  fork mode, model, and reasoning effort. The child is not asked to self-report
  runtime identity that its surface cannot observe; it reports the effective
  permission boundary, its operational constraint, and that it performed no
  task, write, or subagent launch. No task execution or file write is allowed
  during this handshake.
- After the combined proof matches the expected custom-agent configuration,
  send the complete minimal plan or task packet to that same agent. Sol must be
  operationally read-only: require either an enforced read-only sandbox or a
  Host-owned before/after changed-path check proving zero Sol writes. Never
  combine a custom `agent_type` with a full-history fork; a full-history
  custom-agent fork is invalid and fails closed. Configuration text, an agent
  label, or a child's unsupported identity claim is not authoritative proof.
  Treat runtime capability and task authorization separately: a surface that
  reports broader technical access does not widen the user-authorized scope and
  is not by itself a blocker for reversible workspace work. Record the actual
  capability, keep the task packet within the parent authorization, and require
  Host-owned baseline/final changed-path checks; any out-of-scope change fails.
  Destructive, credential-bearing, production, or other irreversible external
  work requires an enforceable matching boundary or explicit user approval for
  that broader capability. If exact model identity, reasoning effort, selected
  agent, fork mode, or the required no-write/scope evidence is unprovable, **Fail
  Closed** and return `BLOCKED`.
- One file has one owner for the whole run. Only when Luna's first failure
  happens before Luna writes any owned file may Sol escalate the same task and
  unchanged scope to Terra once, rather than retrying Luna indefinitely. If
  Luna has written any owned file before failing, Luna retains all ownership;
  only the original Luna owner may receive one focused fix, otherwise return
  `BLOCKED`. Terra's write state is never the escalation gate.

### Selective challenge

Ordinary, standard, low-risk tasks use zero challenge calls. Sol may add at
most one selective challenge task only for high-consequence work, cross-module
or shared interface changes, destructive or security-sensitive work, ambiguous
root cause, weak or conflicting evidence, or an unresolved Requirement ID.
The challenge is a read-only evidence-gathering task with `write_scope: []`.
It returns findings and evidence, cannot approve the candidate, and cannot issue
the final verdict. Sol remains the sole final reviewer and arbitrates every
finding.

## Workflow

1. Sol extracts stable Requirement IDs and writes the smallest useful plan.
2. Independent tasks with disjoint write scopes may run in the same stage.
3. Dependent or overlapping tasks run in later stages.
4. Luna Max or Terra High executes and self-checks each assigned task.
5. Sol reviews the original request, real files, the complete diff, verification
   quality, and Requirement coverage before reading worker summaries and
   deciding `PASS`, `FIX`, or `BLOCKED`.

## Execution continuity and planning convergence

For authorized execution, a plan is not a stop point. Stop or pause only for a
new permission request, an irreversible choice requiring confirmation, or a
real blocker, or an explicit user cancellation, replacement, or redirection of
the current request; these are the only stop gates. Otherwise continue through
the approved stages.

An explicit user cancellation, replacement, or redirection stops the old plan
and requires re-planning from the new request. Substantive user steering is not
an ordinary status inquiry; do not continue old-plan execution while Sol
re-plans.

An ordinary status question or status inquiry does not pause authorized work;
it requires no new permission and is not a blocker. Report the current state
and continue the existing plan and evidence loop.

Sol's planning has a host-stated planning timebox. Within the planning timebox,
Sol must converge to a plan, a determination, or a concrete evidence gap. The
plan, determination, or evidence gap must be produced before the planning
timebox ends. Extended analysis without convergence is not progress.

If a later or downstream stage is blocked, deliver the earlier or prior stage
when it is evidence-complete, including its artifact and evidence. Partial
delivery is allowed only when the completed stage is evidence-complete; only
the unresolved downstream work remains blocked.

## Sol plan

```yaml
goal: "The user's final outcome"
done_when:
  - id: REQ-1
    criterion: "An observable completion criterion"
    evidence: "Required evidence for this criterion"
tasks:
  - id: task-a
    task: "One clear task"
    requirements: [REQ-1]
    write_scope: ["owned/path"]
    do_not_touch: ["all other paths"]
    expected_result: "What must be observable"
    verification: "Exact command or procedure and passing condition"
    required_evidence: "Evidence bound to the final candidate"
    context: "Optional relevant input"
stages:
  - [task-a]
```

Sol uses the minimum number of selected workers needed. A stage may launch only as
many ready tasks as live capacity allows; excess tasks wait in the next batch.
No fixed worker maximum is promised by this Skill.

## Shared execution task

Every delegated task uses this complete packet. `Context` is optional; every
other field is required.

```text
Task ID: <stable task id>
Task: <one bounded task>
Requirement IDs: <REQ-1, REQ-2>
Context: <optional files, evidence, or prior-stage result>
Write scope: <exact writable paths>
Do not touch: <excluded paths and side effects>
Expected result: <observable acceptance condition>
Verification:
  Procedure: <exact command or procedure>
  Passing condition: <falsifiable passing condition>
Required evidence: <diff, output, artifact, or observation bound to the final candidate>
```

An incomplete, contradictory, or unauthorized packet is `BLOCKED`; the worker must
not guess the missing scope.

## Shared execution result

```text
Task ID: <task id>
Status: PASS | BLOCKED
Summary: <what happened>
Changed: <exact files, or None>
Requirement coverage: <each assigned REQ-ID and its evidence>
Verification: <commands and exact results>
Evidence: <diff, test, build, log, or artifact evidence bound to the final candidate>
Failure class: runtime | timeout | model_identity | permission | dependency | scope | verification | evidence_quality | conflict | none
Blocker: <None or the concrete blocker>
```

Evidence must bind to the final candidate identity, represented by a commit+diff
identity or an exact changed-file snapshot. If the candidate changes after
verification, prior evidence is stale and affected verification must be rerun
before `PASS`. A top-level `Candidate` result field is not added.

transport/spawn `completed` only proves delivery lifecycle completion; it cannot substitute for a structured Luna `PASS` or Terra `PASS` (that is, a structured worker `PASS`), Verification/Evidence/changed-path proof, or Sol review.

If transport/spawn reports `completed` without a structured result, allow
exactly one result-only follow-up to the same worker. This result-only follow-up
authorizes no new write and no re-execution. If it still cannot retrieve a
structured result bound to the final candidate, return `BLOCKED`; do not launch
another retrieval.

The worker may return `PASS` for its assigned task only. Sol decides whether the
overall work is complete.

## Scheduling and ownership

- One file has one owner for the entire run.
- Multiple workers may read the same file, but they must not write it
  concurrently.
- A shared integration file has one worker owner.
- If write scopes overlap or the overlap is uncertain, merge the tasks or
  schedule them sequentially.
- Preserve unrelated uncommitted user changes and verify the final real diff.

## Review and correction

The final gate uses the closed verdict vocabulary `PASS | FIX | BLOCKED`.
Residual suggestions or optional improvements stay separate and do not change
`PASS`; an unsatisfied Requirement ID is never residual work.

Sol performs an artifact-first review in this order: original request and
`done_when`; repository baseline and changed paths; actual files and complete
diff; verification output and artifacts; Requirement coverage; only then the
worker summary or worker self-assessment. A worker `PASS` is an untrusted claim,
not evidence.

Sol must verify the verifier, not only its exit status: the procedure must run
against the correct final candidate, exercise the intended requirement, use the
right scope, and produce the required evidence. A wrong scope, tautological or
existence-only check, unexpected test/lockfile rewrite, or unverifiable claim is
`FIX` or `BLOCKED` under `evidence_quality`.

Sol's final review includes this compact matrix:

```yaml
verdict: PASS | FIX | BLOCKED
requirements_coverage:
  - requirement: REQ-1
    status: satisfied | unsatisfied | blocked
    evidence: "Exact file, diff, command output, or artifact"
findings: []
residual_suggestions: []
```

`PASS` requires every Requirement ID to be satisfied and evidenced. Evidence-free
`PASS`, out-of-scope writes, failed verification, conflicts, or missed criteria
cannot pass review. Sol may issue at most one focused fix to the original owner
without expanding its write scope. A second failure is `BLOCKED`.

Every Correction Packet keeps the original owner and original scope, and contains
`Failure class: runtime | timeout | model_identity | permission | dependency | scope | verification | evidence_quality | conflict | none`
plus a `Delta` that changes the same-scope task packet or adds new evidence. The
`none` class is valid only when no failure occurred; any failure uses another
allowed class. The same task packet with no new evidence is `BLOCKED` and must
not be relaunched.

User urgency, requests to hurry, or saying "do not stop" cannot lower, relax,
or reduce the evidence or verification threshold. The evidence threshold
remains unchanged and every safety gate still applies.

## Resume packet (long tasks only)

Resume packets are only for tasks expected to cross context compression, suffer a
session interruption, or run for a long time. The minimal safe packet contains
`run_id`, `goal`, `completed`, `in_flight`, `ownership`,
`requirement_coverage`, `candidate_identity`, `attempts`, `artifact_location`,
and `next_action`. Resume must not redispatch completed tasks or reset retry
attempts. A changed or mismatched `candidate_identity` requires Sol to re-plan
or return `BLOCKED`; never reuse stale evidence.
Short and Direct tasks never generate a resume packet.

Deletion, deployment, production changes, accounts, payment, credentials, or
other external side effects require explicit user authorization before work
begins.

See [orchestration.md](references/orchestration.md) for the operating contract
and [runtime-notes.md](references/runtime-notes.md) for internal dispatch rules.
