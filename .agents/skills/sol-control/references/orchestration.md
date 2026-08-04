# Sol Control orchestration contract

This reference defines the operating contract. Sol owns every scheduling and
completion decision; Luna Max or Terra High owns bounded execution.

## 1. Start and route

- Explicit `$sol-control` invocation starts Sol.
- Ordinary simple work without explicit invocation remains direct.
- Planning-only or review-only work may stop after Sol and use zero workers (and therefore zero Luna workers).
- Execution work uses the minimum useful number of workers selected by Sol.

Sol is the only controller and final reviewer; this is not a permanent agent
team. Route Luna Max only to clear, low-ambiguity, falsifiable, small context,
mechanical, or high-throughput work. Route Terra High to cross-module work,
long-context investigation, ambiguous debugging, shared interface judgment, or
high-risk implementation. Terra never plans or approves the overall task.

Before dispatch, prove exact model identity, reasoning effort, selected custom
agent, and effective inherited permission boundary. If that proof is unavailable,
**Fail Closed** and return `BLOCKED` rather than substituting a nearby model.

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
  - "Observable criterion with evidence"
tasks:
  - id: task-a
    task: "One bounded action"
    write_scope: ["exact/path"]
    do_not_touch: ["excluded/path"]
    expected_result: "Observable result"
    verification: "Exact command or procedure"
    context: "Optional input"
stages:
  - [task-a, task-b]
  - [task-c]
```

`context` is optional. All other task fields are required. Each `done_when`
criterion must map to inspectable evidence or an exact verification.

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
Context: <optional files, evidence, or prior-stage result>
Write scope: <exact writable paths>
Do not touch: <excluded paths and side effects>
Expected result: <observable acceptance condition>
Verification: <exact command or procedure and passing condition>
```

Luna or Terra returns `BLOCKED` without writing if a required field is missing, scope is
contradictory, a dependency is absent, or authorization cannot be proved.

## 6. Shared execution result

```text
Task ID: <task id>
Status: PASS | BLOCKED
Summary: <what happened>
Changed: <exact files, or None>
Verification: <commands, exit status, and concise output>
Evidence: <diff, test, build, log, or artifact location bound to the final candidate>
Failure class: runtime | model_identity | permission | dependency | scope | verification | conflict | none
Blocker: <None or the concrete blocker>
```

`PASS` requires every assigned acceptance condition and verification to be
evidenced. Luna or Terra approves only its bounded task; neither approves the
overall project.

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

Sol inspects the original request, `done_when`, real files, complete diff,
verification output, build or artifact results, and every worker result. It also
checks that tasks integrate cleanly and unrelated user edits remain intact.

Sol returns exactly one verdict:

- `PASS`: all completion criteria and required evidence are satisfied.
- `FIX`: one concrete defect can be corrected inside the original owner's
  unchanged scope.
- `BLOCKED`: permissions, dependencies, runtime selection, scope, conflicts,
  or verification prevent a defensible completion claim.

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
`model_identity`, `permission`, `dependency`, `scope`, `verification`, `conflict`,
or `none`, plus a `Delta` that changes the same-scope task packet or adds new
evidence. The `none` class is valid only when no failure occurred; any failure
uses another allowed class. An identical task packet with no new evidence is
`BLOCKED` and must not be relaunched.

## 9. Resume packet (long tasks only)

Resume is only for tasks expected to cross context compression, be interrupted,
or run for a long time. Its minimal packet contains only `goal`, `completed`,
`in_flight`, `artifact_location`, and `next_action`. Short and Direct tasks do not
generate a resume packet.

## 10. Safety boundary

The dispatcher cannot widen user authorization or the parent permission
boundary. Deletion, deployment, production changes, accounts, payment,
credentials, and external side effects require explicit authorization. No
result summary substitutes for inspection of real artifacts and evidence.
