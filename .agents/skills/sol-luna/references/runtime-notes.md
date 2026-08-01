# Internal runtime notes

This file is for runtime implementers, not a user-selectable workflow.

## Dispatch surfaces

When the surface proves that Sol can directly launch a custom Luna Max worker,
Sol may perform the launch. When nested launch is unavailable or unproved, the
Host launches Luna strictly from Sol's approved plan and returns the results to
Sol for review. The Host is a technical dispatcher, not a third orchestration
role; all task count, ownership, stage, and review decisions remain Sol's.

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

## Write safety

- One file has one owner across the run.
- A shared integration file has one owner.
- Overlapping or uncertain write scopes do not launch concurrently.
- Preserve unrelated dirty-worktree changes; never clean, reset, restore, or
  overwrite them to make integration easier.
- The Host verifies actual changed paths and command evidence before returning
  results to Sol.

The parent retains authorization, workspace safety, integration, final command
execution, and the user reply. These runtime responsibilities do not change the
two-role product model.
