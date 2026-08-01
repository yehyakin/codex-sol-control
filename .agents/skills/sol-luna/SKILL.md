---
name: sol-luna
description: Use when the user explicitly invokes $sol-luna or asks for Sol-controlled execution of a complex, multi-part, parallelizable, or high-consequence task.
---

# Sol Luna

Sol is the single controller. One or more Luna Max workers execute clear tasks,
verify their results, and return evidence for Sol to review.

Ordinary simple work stays direct unless the user explicitly invokes
`$sol-luna`. An explicit invocation always starts with Sol. Planning-only work may use zero Luna workers.

## Roles

- **Sol:** understand the real goal, define `done_when`, split work, assign file
  ownership, schedule stages, and review the actual result. Sol is read-only and
  does not perform bulk implementation.
- **Luna Max:** execute exactly one assigned task, modify only its write scope,
  run the required verification, and return evidence. Luna does not redesign
  the plan, broaden scope, create subagents, or approve the overall task.

## Workflow

1. Sol writes the smallest useful plan.
2. Independent tasks with disjoint write scopes may run in the same stage.
3. Dependent or overlapping tasks run in later stages.
4. Luna Max executes and self-checks each assigned task.
5. Sol reviews real files, the diff, test or build output, and requirement
   coverage before deciding `PASS`, `FIX`, or `BLOCKED`.

## Sol plan

```yaml
goal: "The user's final outcome"
done_when:
  - "An observable completion criterion"
tasks:
  - id: task-a
    task: "One clear task"
    write_scope: ["owned/path"]
    do_not_touch: ["all other paths"]
    expected_result: "What must be observable"
    verification: "Exact command or procedure"
    context: "Optional relevant input"
stages:
  - [task-a]
```

Sol uses the minimum number of Luna workers needed. A stage may launch only as
many ready tasks as live capacity allows; excess tasks wait in the next batch.
No fixed worker maximum is promised by this Skill.

## Luna task

Every delegated task uses this complete packet. `Context` is optional; every
other field is required.

```text
Task ID: <stable task id>
Task: <one bounded task>
Context: <optional files, evidence, or prior-stage result>
Write scope: <exact writable paths>
Do not touch: <excluded paths and side effects>
Expected result: <observable acceptance condition>
Verification: <exact command or procedure and passing condition>
```

An incomplete, contradictory, or unauthorized packet is `BLOCKED`; Luna must
not guess the missing scope.

## Luna result

```text
Task ID: <task id>
Status: PASS | BLOCKED
Summary: <what happened>
Changed: <exact files, or None>
Verification: <commands and exact results>
Evidence: <diff, test, build, log, or artifact evidence>
Blocker: <None or the concrete blocker>
```

Luna may return `PASS` for its assigned task only. Sol decides whether the
overall work is complete.

## Scheduling and ownership

- One file has one owner for the entire run.
- Multiple Luna workers may read the same file, but they must not write it
  concurrently.
- A shared integration file has one Luna owner.
- If write scopes overlap or the overlap is uncertain, merge the tasks or
  schedule them sequentially.
- Preserve unrelated uncommitted user changes and verify the final real diff.

## Review and correction

Sol returns `PASS | FIX | BLOCKED`. Evidence-free `PASS`, out-of-scope writes,
failed verification, conflicts, or missed criteria cannot pass review. Sol may
issue at most one focused fix to the original owner without expanding its write
scope. A second failure is `BLOCKED`.

Deletion, deployment, production changes, accounts, payment, credentials, or
other external side effects require explicit user authorization before work
begins.

See [orchestration.md](references/orchestration.md) for the operating contract
and [runtime-notes.md](references/runtime-notes.md) for internal dispatch rules.
