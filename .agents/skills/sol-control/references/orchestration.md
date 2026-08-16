# Sol Control orchestration contract

This reference defines the operating contract. Sol owns every scheduling and
completion decision; Luna Max or Terra High owns bounded execution.

## 1. Start and route

- Explicit `$sol-control` invocation starts Sol.
- The Host starts `sol-controller` with `fork_turns="none"` for an identity-only
  handshake. The authoritative Host/tool contract and launch record prove the
  requested `agent_type`, fork mode, model, and reasoning effort. Sol reports
  its effective permission boundary, operational read-only constraint, and zero
  task/write/subagent activity without planning or writing. The child is not
  asked to self-report runtime identity that the surface cannot expose. Only
  after the combined proof matches does the Host send the plan request to that
  same Sol. Every worker uses the same two-turn handshake before it receives a
  task packet. A full-history custom-agent fork is invalid and fails closed.
- Ordinary simple work without explicit invocation remains direct.
- Planning-only or review-only work may stop after Sol and use zero workers (and therefore zero Luna workers).
- Execution work uses the minimum useful number of workers selected by Sol.

Sol is the only controller and sole final reviewer; this is not a permanent agent
team. Route Luna Max only to clear, low-ambiguity, falsifiable, small context,
mechanical, or high-throughput work. Route Terra High to cross-module work,
long-context investigation, ambiguous debugging, shared interface judgment, or
high-risk implementation. Terra never plans or approves the overall task.

Ordinary, standard, low-risk work has no extra challenge call. Sol may schedule
at most one selective challenge for high-consequence work, cross-module or
shared interface changes, destructive or security-sensitive work, ambiguous
root cause, weak or conflicting evidence, or an unresolved Requirement ID. The
challenge is a bounded read-only task with `write_scope: []`. It produces
findings and evidence only; it cannot approve the candidate, issue a final
verdict, create subagents, or become a second controller. Sol arbitrates its
findings and remains the only controller and sole final reviewer.

Before task execution or any write, combine the authoritative Host/tool role
mapping, parent launch record, and child's permission/no-side-effect handshake
to prove exact model identity, reasoning effort, selected custom agent, fork
mode, and the actual effective technical capability. Configuration text, an
agent label, or a child's unsupported identity claim is not authoritative proof.
Capability is not authorization: broader technical access reported by a runtime
does not enlarge the user-approved task or `write_scope`, and does not by itself
block reversible workspace work. Sol must record the mismatch and require a
Host-owned baseline/final changed-path check for every such agent turn. Sol must
also have either an enforced read-only sandbox or a Host-owned before/after
changed-path check proving zero Sol writes. Any out-of-scope change fails.
Destructive, credential-bearing, production, or irreversible external work
requires an enforceable matching boundary or explicit user approval for the
broader capability. If identity, fork, authorization, or required scope/no-write
evidence is unavailable or mismatched, do not send the task: **Fail Closed** and
return `BLOCKED` rather than silently weakening the boundary.

For authorized execution, a plan is not a stop point. Stop or pause only for a
new permission request, an irreversible choice requiring confirmation, or a
real blocker, or an explicit user cancellation, replacement, or redirection of
the current request; these are the only stop gates. Ordinary status questions or
status inquiries do not pause authorized work, require no new permission, and are
not blockers.

An explicit user cancellation, replacement, or redirection stops the old plan
and requires re-planning from the new request. Substantive user steering is not
an ordinary status inquiry; do not continue old-plan execution while Sol
re-plans.

Sol's planning has a host-stated planning timebox. Within that planning timebox,
Sol must converge to a plan, a determination, or a concrete evidence gap. The
plan, determination, or evidence gap must be produced before the planning
timebox ends; extended analysis without convergence is not progress.

When a later or downstream stage is blocked, deliver an earlier or prior stage
that is evidence-complete with its artifact and evidence. Partial delivery is
allowed only when the completed stage is evidence-complete; only unresolved
downstream work remains blocked.

## 2. Sol plan

Sol produces only this top-level shape:

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
    write_scope: ["exact/path"]
    do_not_touch: ["excluded/path"]
    expected_result: "Observable result"
    verification: "Exact procedure and passing condition"
    required_evidence: "Evidence bound to the final candidate"
    context: "Optional input"
stages:
  - [task-a, task-b]
  - [task-c]
```

`context` is optional. All other task fields are required. Every `done_when`
item has a stable `REQ-*` ID, criterion, and required evidence. Every task lists
the Requirement IDs it covers. Sol rejects a plan with an unowned Requirement
ID, a task that maps to no Requirement ID, or a criterion without falsifiable
evidence.

## 3. Stages and live capacity

Task IDs in one stage are independent and may run concurrently only when their
write scopes are disjoint. Later stages wait for earlier stages to finish and
pass review. At every launch, the dispatcher checks live capacity and starts
only the ready tasks that fit. Remaining tasks stay queued for another batch;
the plan never assumes a fixed worker count.

If dependency order or write overlap is uncertain, schedule sequentially.

## 4. One file, one owner

Every writable file has one owner for the entire run. Read-only analysis may be
parallel, but two workers never modify the same file. A shared integration
file also has one owner. Alternative proposals may be collected read-only;
after Sol selects a proposal, one worker performs the write.

Before launch, reject a stage that contains overlapping write scopes. Before
integration, compare the real changed paths with every assigned scope and
preserve unrelated dirty-worktree changes.

## 5. Shared execution task

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

Luna or Terra returns `BLOCKED` without writing if a required field is missing, scope is
contradictory, a dependency is absent, or authorization cannot be proved.

## 6. Shared execution result

```text
Task ID: <task id>
Status: PASS | BLOCKED
Summary: <what happened>
Changed: <exact files, or None>
Requirement coverage: <each assigned REQ-ID and its evidence>
Verification: <commands, exit status, and concise output>
Evidence: <diff, test, build, log, or artifact location bound to the final candidate>
Failure class: runtime | timeout | model_identity | permission | dependency | scope | verification | evidence_quality | conflict | none
Blocker: <None or the concrete blocker>
```

`PASS` requires every assigned Requirement ID, acceptance condition, and
verification to be evidenced. Luna or Terra approves only completion of its
bounded task; neither approves the overall project. Its `PASS` remains an
untrusted claim until Sol inspects the candidate and evidence.

Evidence must bind to the final candidate identity using either a commit+diff
identity or an exact changed-file snapshot. If the candidate changes after
verification, the old evidence is stale and affected verification must be rerun.
Do not add a top-level `Candidate` field to the worker result.

Transport/spawn `completed` only proves delivery lifecycle completion. It cannot
substitute for a structured Luna `PASS` or Terra `PASS` (that is, a structured worker `PASS`), Verification/Evidence/changed-path proof,
or Sol review.

If transport/spawn reports `completed` without a structured result, allow exactly
one result-only follow-up to the same worker. The result-only follow-up may not
authorize a new write or re-execution. If it still cannot retrieve a structured
result bound to the final candidate, return `BLOCKED`; do not launch another
retrieval.

## 7. Sol review

Sol uses artifact-first review and deliberately delays worker conclusions. It
inspects in this order:

1. original request and every `done_when` Requirement ID;
2. repository baseline, real changed paths, ownership, actual files, and the
   complete diff;
3. verification output and build, runtime, UI, research, or document artifacts;
4. Requirement coverage and integration behavior;
5. only then worker summaries, self-assessments, and challenge findings.

A worker `PASS` is an untrusted claim, not evidence. Sol also checks that tasks
integrate cleanly and unrelated user edits remain intact.

### Verification quality

Sol must verify the verifier before accepting a green command. The check must:

- run against the correct final candidate;
- exercise the intended requirement rather than a nearby behavior;
- use the correct scope and existing project toolchain;
- have a falsifiable passing condition and required evidence;
- avoid unauthorized rewrites to tracked tests, fixtures, lockfiles, or policy
  files.

A wrong scope, tautological assertion, existence-only check, silently skipped
test, unexpected test/lockfile rewrite, or evidence that cannot be tied to the
candidate is `FIX` or `BLOCKED` with failure class `evidence_quality`.

Sol returns exactly one verdict from the closed vocabulary:

- `PASS`: all completion criteria and required evidence are satisfied.
- `FIX`: one concrete defect can be corrected inside the original owner's
  unchanged scope.
- `BLOCKED`: permissions, dependencies, runtime selection, scope, conflicts,
  or verification prevent a defensible completion claim.

Residual suggestions and optional improvements are separate from the verdict.
They do not change `PASS`, but an unsatisfied Requirement ID can never be
reclassified as residual work.

```yaml
verdict: PASS | FIX | BLOCKED
requirements_coverage:
  - requirement: REQ-1
    status: satisfied | unsatisfied | blocked
    evidence: "Exact file, diff, command output, or artifact"
findings: []
residual_suggestions: []
```

`PASS` requires every Requirement ID to be satisfied and evidenced.

Sol must reject an evidence-free worker `PASS`, an out-of-scope write, an omitted
criterion, or a failed command.

Only when Luna's first failure happens before Luna writes any owned file may Sol
perform one bounded escalation of the same task and unchanged scope to Terra
instead of unbounded Luna retries. If Luna has written any owned file before
failing, Luna retains all ownership; only the original Luna owner may receive
one focused fix, otherwise return `BLOCKED`. Terra's write state is never the
escalation gate. The packet, authorization boundary, evidence freshness,
correction rules, and scope remain unchanged.

## 8. Focused fix

At most one focused fix is allowed for a task:

```text
Task ID: <original-id>-fix
Issue: <observed defect and evidence>
Required correction: <smallest authorized repair>
Scope: <the original owner's unchanged write scope>
Verification: <exact regression command or procedure>
```

The same owner performs the fix. A second failure, expanded scope, or new owner
conflict becomes `BLOCKED`; do not retry indefinitely.

User urgency, requests to hurry, or saying "do not stop" cannot lower, relax, or
reduce the evidence or verification threshold. The evidence threshold remains
unchanged and every safety gate still applies.

The focused correction is a Correction Packet with the original owner and
unchanged scope. It must include `Failure class` from exactly `runtime`,
`timeout`, `model_identity`, `permission`, `dependency`, `scope`, `verification`,
`evidence_quality`, `conflict`, or `none`, plus a `Delta` that changes the
same-scope task packet or adds new
evidence. The `none` class is valid only when no failure occurred; any failure
uses another allowed class. An identical task packet with no new evidence is
`BLOCKED` and must not be relaunched.

## 9. Resume packet (long tasks only)

Resume is only for tasks expected to cross context compression, be interrupted,
or run for a long time. Its minimal safe packet contains `run_id`, `goal`,
`completed`, `in_flight`, `ownership`, `requirement_coverage`,
`candidate_identity`, `attempts`, `artifact_location`, and `next_action`.

On resume, the Host and Sol compare the current repository state with
`candidate_identity`, retain ownership for every path already written, and keep
the recorded attempt counts. Resume must not redispatch or relaunch completed
tasks, duplicate a successful verification, or reset an attempt/retry budget.
A changed or mismatched `candidate_identity` invalidates affected evidence and
requires Sol to re-plan or return `BLOCKED`. Short and Direct tasks do not
generate a resume packet.

## 10. Safety boundary

The dispatcher cannot widen user authorization or the parent permission
boundary. Deletion, deployment, production changes, accounts, payment,
credentials, and external side effects require explicit authorization. No
result summary substitutes for inspection of real artifacts and evidence.
