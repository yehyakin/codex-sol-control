---
name: orchestrate-sol-luna
description: Use when a task needs adaptive routing between direct work, planning assistance, bounded execution, or high-risk orchestration.
---

# Orchestrate Sol Luna

This is the universal entrypoint for bounded work routed through Main, `sol-planner`, and `luna-max-worker`. Main owns authorization, integration, final verification, and the user reply. Use [routing-protocol.md](references/routing-protocol.md) for the complete packet and evidence contract.

## Routing levels

- **Level 0 — Direct:** Main performs the work with zero delegation.
- **Level 1 — Sol Assist:** Main launches one `sol-planner`; Luna is not forced.
- **Level 2 — Sol -> Luna:** Sol produces the execution graph and complete Luna packet; Luna executes bounded work; Sol reviews the result.
- **Level 3 — High-Risk:** explicit authorization, a recovery checkpoint, exclusive file owners, and stop conditions are required before execution.

Disjoint writes may run in parallel, dependencies run in waves, and a file has one writer. The default is 1-3 Luna workers, never above the runtime cap. Main preserves unrelated user changes and owns the final diff.

## Runtime selection

**Compatibility** is the default: Main launches Sol, then Luna, then Sol review. **Native Nested** is allowed only after a live probe proves custom-agent selection, the exact model/effort switch, and effective depth >=2. Native changes only who launches Luna; the packet, scopes, evidence, and Sol review do not change.

**Fail Closed** when an exact agent, model, effort, or permission selection cannot be proved. There is no silent fallback and no identity spoofing.

## Role boundary

`sol-planner` plans, maps dependencies and write ownership, arbitrates, and reviews real diffs, artifacts, and evidence; it does not perform bulk mechanical implementation. `luna-max-worker` acts only on a complete packet, inherits the parent permission boundary, verifies its work, returns exact evidence, never spawns or creates a subagent, and never self-approves.

At most one targeted retry is allowed through a Correction Packet. Missing evidence, timeout, conflict, unauthorized scope, or an unproved runtime selection stops the route.
