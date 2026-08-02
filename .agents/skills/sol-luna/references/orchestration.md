# Sol Luna orchestration contract

This reference defines the operating contract. Sol owns every scheduling and
completion decision; Luna Max owns bounded execution.

## 1. Start and route

- Explicit `$sol-luna` invocation starts Sol.
- Ordinary simple work without explicit invocation remains direct.
- Planning-only or review-only work may stop after Sol and use zero Luna.
- Execution work uses the minimum useful number of Luna workers.

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
parallel, but two Luna workers never modify the same file. A shared integration
file also has one owner. Alternative proposals may be collected read-only;
after Sol selects a proposal, one Luna performs the write.

Before launch, reject a stage that contains overlapping write scopes. Before
integration, compare the real changed paths with every assigned scope and
preserve unrelated dirty-worktree changes.

## 5. Luna task

```text
Task ID: <stable task id>
Task: <one bounded task>
Context: <optional files, evidence, or prior-stage result>
Write scope: <exact writable paths>
Do not touch: <excluded paths and side effects>
Expected result: <observable acceptance condition>
Verification: <exact command or procedure and passing condition>
```

Luna returns `BLOCKED` without writing if a required field is missing, scope is
contradictory, a dependency is absent, or authorization cannot be proved.

## 6. Luna result

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
evidenced. Luna approves only its bounded task; it never approves the overall
project.

Evidence must bind to the final candidate identity using either a commit+diff
identity or an exact changed-file snapshot. If the candidate changes after
verification, the old evidence is stale and affected verification must be rerun.
Do not add a top-level `Candidate` field to the Luna result.

Transport/spawn `completed` only proves delivery lifecycle completion. It cannot
substitute for a structured Luna `PASS`, Verification/Evidence/changed-path proof,
or Sol review.

## 7. Sol review

Sol inspects the original request, `done_when`, real files, complete diff,
verification output, build or artifact results, and every Luna result. It also
checks that tasks integrate cleanly and unrelated user edits remain intact.

Sol returns exactly one verdict:

- `PASS`: all completion criteria and required evidence are satisfied.
- `FIX`: one concrete defect can be corrected inside the original owner's
  unchanged scope.
- `BLOCKED`: permissions, dependencies, runtime selection, scope, conflicts,
  or verification prevent a defensible completion claim.

Sol must reject an evidence-free Luna `PASS`, an out-of-scope write, an omitted
criterion, or a failed command.

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
