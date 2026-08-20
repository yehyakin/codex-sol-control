# Codex PROVE runtime profiles

Use this reference for agent selection, identity proof, dispatch mode, capacity,
model replacement, and runtime failure handling.

## Contents

1. Stable roles and current defaults
2. Two-turn launch proof
3. Native Nested and Compatibility
4. Capacity and batching
5. Model replacement
6. Failure rules

## 1. Stable roles and current defaults

The role names are deliberately model-neutral:

| Agent type | Capability role | Default model | Reasoning | Requested sandbox |
|---|---|---|---|---|
| `prove-controller` | planning, routing, ownership, sole final review | `gpt-5.6-sol` | `high` | `read-only` |
| `prove-complex-worker` | ambiguous, cross-module, long-context, high-consequence execution | `gpt-5.6-terra` | `high` | `workspace-write` |
| `prove-efficient-worker` | clear, bounded, falsifiable, high-throughput execution | `gpt-5.6-luna` | `max` | `workspace-write` |

These values are the v1.0 default profile, not the product identity. Plans use
`complex` and `efficient`; they do not hard-code a model brand. Never silently
replace a configured model, reasoning effort, agent type, or permission
boundary.

## 2. Two-turn launch proof

Launch each custom agent with `fork_turns="none"`.

### Turn 1: identity and capability only

The Host records:

- requested `agent_type`;
- authoritative role-to-model and role-to-reasoning mapping exposed by the
  current collaboration tool/runtime;
- `fork_turns="none"`;
- requested sandbox or operational boundary.

The child reports only:

- effective technical capability it can observe;
- operational constraint it will follow;
- zero task activity;
- zero repository writes;
- zero subagent launches.

Do not ask the child to self-report model or reasoning metadata its surface does
not expose. Do not inspect the repository or plan during the handshake.

The Host combines its authoritative launch record with the child's
no-side-effect statement. TOML contents or the child's name alone are not proof.
If selected identity, model, reasoning effort, or fork mode cannot be proved,
stop before sending work and return `BLOCKED`.

### Turn 2: bounded work

Send the complete controller request or worker task packet to the same verified
agent. Reusing the verified agent preserves the identity proof without leaking
the parent conversation. Workers must not create subagents.

The controller remains operationally read-only. Prefer an enforced read-only
sandbox. When the runtime exposes broader access, use Host-owned before/after
changed-path snapshots to prove zero controller writes.

## 3. Native Nested and Compatibility

Both modes use the same requirement graph, task packet, role profiles, ownership
rules, verification threshold, result schema, and final review.

### Native Nested

Use only when the current runtime proves all of the following:

- custom agent selection works;
- effective `max_depth >= 2`;
- the controller can launch workers;
- each model and reasoning selection is proven by the Host/tool contract;
- required permission and changed-path controls are available.

Flow:

```text
Host -> prove-controller -> prove-complex-worker / prove-efficient-worker
                         -> prove-controller review -> Host delivery
```

The controller may create only the minimum ready workers from its plan and must
respect live capacity. Workers cannot recurse.

### Compatibility

Use when nesting is unavailable, unstable, over capacity, or unproven:

```text
Host -> prove-controller plan
Host -> workers from that plan
Host -> prove-controller final review
Host -> delivery
```

The Host is a dispatcher, not a second controller: it follows the controller's
task graph, preserves ownership, supplies worker results plus real artifacts,
and returns the review packet to the same verified controller when possible.

Never claim Native Nested succeeded without a real nested launch record.
Compatibility is a first-class mode, not an unreported downgrade.

## 4. Capacity and batching

Capacity is runtime state. Read the current collaboration limit before launch.
Do not encode a universal worker maximum in the Skill.

- Default to one to three workers when that is sufficient.
- Launch only dependency-ready tasks whose write scopes are disjoint.
- If the ready frontier exceeds available slots, dispatch it in batches.
- Keep one slot for the Host/controller relationship when the runtime requires
  it.
- Do not create agents to demonstrate parallelism or duplicate the same fact.

Report the observed limit when it materially constrains the plan.

## 5. Model replacement

When OpenAI publishes a better model, keep the brand, invocation, role names,
task schema, and evidence gates stable. Change only the capability profile after
verification:

1. Establish a matched evaluation against the current profile.
2. Check model availability and exact runtime selection.
3. Update the relevant `.codex/agents/prove-*.toml` model and reasoning fields.
4. Update this default-profile table, validators, and release notes.
5. Run static, lifecycle, routing, fail-closed, and fresh-session tests.
6. Publish the profile change with measured limitations.

Do not rename Codex PROVE for a model generation. Do not infer that a newer or
more expensive model is automatically the right controller or worker.

## 6. Failure rules

- **Agent/model/reasoning unprovable:** `BLOCKED`, never label-based
  impersonation.
- **Requested custom role unavailable:** report the unavailable role and stop or
  use Compatibility only if the exact configured role can still be proven.
- **Broader capability than authorization:** record it; for reversible workspace
  work use Host-owned scope checks. For destructive/external work require an
  enforceable boundary or explicit broader authorization.
- **Worker timeout or missing result:** one result-only recovery; then one narrow
  correction only when ownership rules permit; otherwise `BLOCKED`.
- **Conflicting worker evidence:** send real artifacts to the controller for
  arbitration; never merge summaries mechanically.
- **Controller writes:** fail the run, preserve evidence, and report the exact
  changed paths.
- **Candidate changed after verification:** mark evidence stale and rerun the
  affected checks.
