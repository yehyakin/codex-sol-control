# Internal runtime notes

This file is for runtime implementers, not a user-selectable workflow.

## Dispatch surfaces

When the surface proves that Sol can directly launch a custom Luna Max worker,
Sol may perform the launch. When nested launch is unavailable or unproved, the
Host launches Luna strictly from Sol's approved plan and returns the results to
Sol for review. The Host is a technical dispatcher, not a third orchestration
role; all task count, ownership, stage, and review decisions remain Sol's.

transport/spawn `completed` only proves delivery lifecycle completion. It cannot substitute for a structured Luna `PASS`, Verification/Evidence/changed-path proof, or Sol review.

## Execution continuity and host recovery

For authorized execution, a plan is not a stop point. Stop or pause only for a
new permission request, an irreversible choice requiring confirmation, or a
real blocker, or an explicit user cancellation, replacement, or redirection of
the current request; these are the only stop gates. Ordinary status questions
and status inquiries do not pause authorized work, require no new permission,
and are not blockers.

An explicit user cancellation, replacement, or redirection stops the old plan
and requires re-planning from the new request. Substantive user steering is not
an ordinary status inquiry; the Host must stop old-plan execution while Sol
re-plans.

The Host supplies a planning timebox. Within that planning timebox, Sol must
converge to a plan, a determination, or a concrete evidence gap. The plan,
determination, or evidence gap must be produced before the planning timebox
ends. Extended analysis without convergence is not progress.

If a later or downstream stage is blocked, return an earlier or prior stage
that is evidence-complete with its artifact and evidence. Partial delivery is
allowed only when the completed stage is evidence-complete; unresolved
downstream work remains blocked.

If transport/spawn reports `completed` without a structured result, the Host may
request exactly one result-only follow-up from the same worker. This follow-up
may not authorize a new write or re-execution. If no structured result bound to
the final candidate is returned, the task is `BLOCKED`; do not perform another
retrieval or relaunch.

User urgency or a request to hurry or "do not stop" cannot lower, relax, or
reduce the evidence or verification threshold. The evidence threshold remains
unchanged.

The older Compatibility and Native Nested labels are implementation history,
not public modes. Neither path changes the plan, packet, ownership, evidence,
or review contract.

## Exact runtime proof

Configuration text and agent names are not proof of execution identity. Every
launch must expose evidence of the selected custom agent, exact model,
reasoning effort, and effective permission boundary:

- `sol-controller`: exact model `gpt-5.6-sol`, reasoning effort `high`,
  read-only;
- `luna-max-worker`: exact model `gpt-5.6-luna`, reasoning effort `max`, with
  effective access no broader than the inherited parent boundary and the
  `workspace-write` ceiling.

If any exact selection cannot be proved, **Fail Closed**. Do not silently
substitute a nearby model, effort, role, or permission profile, and do not use
an agent label to spoof identity.

Luna must not spawn or create subagents. A fresh context is preferred when
switching custom agent types so parent model or role identity is not inherited
accidentally.

## Capacity and batching

Read live capacity before each launch. Start only the ready tasks that fit;
queue the rest for another batch. Never claim a fixed Luna maximum from this
Skill. A reduced capacity changes batch size, not Sol's approved dependency or
ownership decisions.

## First-artifact checkpoint

For an implementation task, the Luna packet should identify the smallest observable first artifact, such as creating the owned file, making the frozen
RED test import the module, or producing one focused failing verification.
Luna must reach that checkpoint within the Host's stated execution timebox or
return `BLOCKED` with the concrete reason. Extended read-only analysis without
an owned artifact, command evidence, or blocker is not progress; the Host may
interrupt the worker after the timebox and re-plan a smaller task through Sol.
An interrupted worker that wrote no files leaves ownership available for a
fresh worker. If it wrote any file, ownership remains with that worker for the
run and the Host must not silently reassign or overwrite it.

## Write safety

- One file has one owner across the run.
- A shared integration file has one owner.
- Overlapping or uncertain write scopes do not launch concurrently.
- Preserve unrelated dirty-worktree changes; never clean, reset, restore, or
  overwrite them to make integration easier.
- The Host verifies actual changed paths and command evidence before returning
  results to Sol.
- Before dispatching a Sol `FIX`, the Host compares its proposed write scope,
  permissions, and side effects with the original Luna packet. Any new path or
  authority makes the current task `BLOCKED`; continue through a separately
  planned task instead of relabeling the expanded work as a focused fix.
- Evidence must bind to the final candidate identity with a commit+diff identity
  or exact changed-file snapshot. If the candidate changes after verification,
  old evidence is stale and affected verification must be rerun before `PASS`.

Correction packets retain the original owner and scope. Their Failure class is
one of `runtime | model_identity | permission | dependency | scope | verification |
conflict | none`, and their Delta is a same-scope task-packet change or new
evidence. `none` is valid only when no failure occurred; any failure must use
one of the other classes. An identical packet with no new evidence is `BLOCKED`
and is not relaunched.

Resume packets are only for long, interrupted, or context-compressed tasks and
contain `goal`, `completed`, `in_flight`, `artifact_location`, and `next_action`.
Short and Direct tasks never generate one.

## Verification environment hygiene

Before running delegated or host-side verification, identify the repository's
package manager from its committed lockfile, scripts, and documented toolchain.
Use that package manager and the repository's existing commands or installed
binaries. Do not invoke a different package manager merely as a command runner:
it may rewrite the dependency layout or create lock/workspace files even when
the intended operation is read-only.

If a verification command unexpectedly changes the worktree or dependency layout, stop, attribute the new paths and timestamps, and restore only artifacts
created by that command from the committed toolchain. Re-check the dirty-path
baseline before continuing or asking Sol to review. Never classify such
environment pollution as a Luna defect without reproducing it after recovery.

The parent retains authorization, workspace safety, integration, final command
execution, and the user reply. These runtime responsibilities do not change the
two-role product model.
