# Orchestrate Sol Luna routing protocol

This reference is the operational contract behind the Skill entrypoint. It is deliberately universal: task packets name the actual files, artifacts, commands, and acceptance criteria for one run.

## Quick reference

| Decision | Required behavior |
| --- | --- |
| Level 0 / Direct | Main does the work; delegation count is zero. |
| Level 1 / Sol Assist | Main launches one Sol for planning or review; no Luna is forced. |
| Level 2 / Sol -> Luna | Sol writes the graph and packet, Luna executes, Sol reviews. |
| Level 3 / High-Risk | Main authorizes first; recovery, ownership, and stop gates are mandatory. |
| Default runtime | Compatibility: Main → Sol → Luna → Sol review. |
| Native Nested | Only after a live probe proves selection, exact model/effort, and depth >=2. |
| Parallelism | Disjoint write scopes may share a wave; dependencies create later waves. |
| Ownership | One writer per file. Read-only analysis may be parallel. |
| Retry | At most one targeted Correction Packet. A second failure is not an open-ended retry. |
| Authority | Main authorizes, integrates, verifies finally, and replies to the user. |

## Non-negotiable invariants

1. Every delegated run retains the parent permission boundary. A child cannot widen read, write, network, credential, or tool access.
2. Exact runtime identity is evidence, not a label. The route must prove the selected agent, model, reasoning effort, and effective permission boundary at launch.
3. No silent fallback, identity spoofing, or substitution of a nearby model/role is allowed. If the required selection cannot be proved, Fail Closed and report the blocker.
4. Luna receives a complete task packet and has no authority to infer missing scope, authorize itself, merge work, or approve its own result.
5. Main remains the authority for authorization, integration, final verification, and the user reply. A Sol or Luna report is evidence, not final approval.

## Choosing a level

### Level 0 — Direct

Use for one narrow, well-understood action whose risk and verification fit within Main. Delegation is exactly zero. Main still checks the requested scope and the final diff or artifact.

### Level 1 — Sol Assist

Use one `sol-planner` when a plan, dependency analysis, ownership map, or arbitration is useful but execution should remain with Main. Luna is not forced. Sol is read-only and returns acceptance criteria plus any risks or open decisions.

### Level 2 — Sol -> Luna

Sol creates an execution graph, assigns exclusive writers, partitions independent work, and emits one complete packet per Luna task. Main launches Luna in Compatibility, or Sol launches it only in proved Native Nested mode. The default count is 1-3 Luna tasks and must never exceed the runtime cap. Sol reviews actual changes, artifacts, and command evidence before Main integrates anything.

### Level 3 — High-Risk

Main records explicit authorization before any write or external side effect. The graph must include a recovery checkpoint, exclusive owners, dependency waves, verification commands, and stop conditions. Stop immediately on an authorization mismatch, scope drift, unproved identity or permission, failed required verification, unresolved writer conflict, or a second failed attempt. Recovery resumes from recorded evidence; it does not guess or replay unsafe work.

## Runtime mode and live probe

Compatibility is the default unless a live probe proves all Native Nested prerequisites. The probe must capture observable runtime evidence for:

- custom-agent selection of `sol-planner` and `luna-max-worker`;
- the exact model and reasoning effort selected for each role;
- effective nesting depth of at least 2; and
- the permission boundary inherited by the nested launch.

Compatibility has one explicit sequence: Main launches Sol, Main launches Luna using the same approved packet, then Main asks Sol for final review. Native changes only who launches Luna: Sol may launch Luna after the proof and authorization gates; Main still owns the packet authority, integration, final verification, and reply. If any exact agent/model/effort/permission selection is not provable in either mode, Fail Closed. Do not claim Native from configuration text alone.

## Sol execution graph

Sol returns one graph before Level 2 or Level 3 execution. The following are the canonical YAML fields; values are concrete for the current task, not promises about a future plan.

```yaml
complexity_level: 2
execution_mode: Compatibility
reasoning: "Why this level, runtime mode, and decomposition fit the request"
acceptance_criteria:
  - "Observable criterion with a matching verification command"
task_graph:
  -
    id: "task-001"
    objective: "Complete one bounded outcome"
    agent: "luna-max-worker"
    mode: "write"
    dependencies: []
    inputs:
      - "Exact paths, artifacts, or values named by the packet"
    read_scope:
      - "Exact paths that may be inspected"
    write_scope:
      - "Exact paths that may be changed"
    forbidden_scope:
      - "All other paths, identities, and side effects"
    deliverable: "Named files or artifact"
    minimum_verification:
      command_or_procedure: "Literal command or reproducible procedure"
      passing_condition: "Expected exit status and observable result"
      required_evidence: "Command output plus diff or artifact evidence"
    can_launch: true
    held_reason: ""
    stop_conditions:
      - "Any scope, authorization, identity, permission, or verification mismatch"
write_ownership:
  - "One exclusive writer per writable file"
conflict_risks:
  - "Overlapping write scopes or contradictory evidence"
integration_owner: "Main"
final_review_required: true
```

`can_launch` describes task readiness for the active dispatcher: Main in Compatibility, or Sol in proved Native Nested. It is true only when dependencies, authorization, ownership, exact identity, permissions, and runtime capacity are satisfied. When false, `held_reason` must name the unmet condition. `task_graph` dependencies form waves. Tasks in one wave must have disjoint `write_scope`; the same file may have one writer across the entire run. Parallel read-only analysis is permitted when it cannot race a write.

## Luna task packet

The packet is text with every field filled. A missing, contradictory, or vague field is a BLOCKED condition; Luna must not invent a value.

```text
Luna Task Packet
Task ID: <stable identifier>
Objective: <one bounded outcome>
Why it matters: <the outcome or risk addressed>
Inputs and evidence: <exact source paths, artifacts, or values>
Read scope: <exact paths that may be read>
Write scope: <exact paths that may be changed>
Forbidden scope: <exact paths, tools, identities, and side effects excluded>
Dependencies: <completed task IDs or none>
Constraints: <permission, runtime, ownership, timeout, and retry limits>
Required deliverable: <named files or artifact>
Acceptance criteria: <observable conditions for PASS>
Minimum verification:
  Command or procedure: <literal command or reproducible procedure>
  Passing condition: <expected exit status and observable result>
  Required evidence: <command output plus diff, artifact, or log>
Stop conditions: <scope drift, conflict, timeout, failure, or missing evidence>
Return format:
  Status: PASS | BLOCKED
  Summary: <what happened, including no-op if applicable>
  Files inspected: <exact paths>
  Files changed: <exact paths, or none>
  Verification performed: <commands or procedures run>
  Exact verification result: <exit status and concise output>
  Evidence: <diff, artifact, log, or test location>
  Assumptions: <assumptions made, or none>
  Risks: <remaining risks, or none>
  Blockers: <empty only for PASS>
```

The packet must preserve the parent boundary and must not contain credentials. `Constraints` carries the runtime, ownership, timeout, and retry limits. Main may issue one Correction Packet for the same narrow issue; it may not turn a failed packet into a broader task.

## Luna return contract

Luna returns this shape without claiming final approval:

```text
Status: PASS | BLOCKED
Summary: <what happened, including no-op if applicable>
Files inspected: <exact paths>
Files changed: <exact paths, or none>
Verification performed: <commands or procedures run>
Exact verification result: <exit status and concise output>
Evidence: <diff, artifact, log, or test location tied to each criterion>
Assumptions: <assumptions made, or none>
Risks: <remaining risks, or none>
Blockers: <empty only for PASS>
```

PASS requires every acceptance criterion, exact file ownership, and every prescribed verification to be evidenced. A command that was not run is not evidence. Luna returns BLOCKED for missing packet data, unavailable selection, scope drift, timeout, failed verification, conflict, or inability to produce exact evidence. Luna does not self-approve; Sol reviews and Main makes the final decision.

## Correction Packet

There is at most one targeted retry. Main creates a Correction Packet only after inspecting the failed evidence; it is not a request to retry until green.

```text
Correction Packet
correction_id: <stable identifier>
parent_task_id: <original task ID>
retry_number: 1
single_narrow_issue: <one observed defect or missing criterion>
failure_evidence: <literal command/result, diff, or artifact evidence>
required_change: <smallest authorized correction>
preserved_read_scope: <unchanged scope>
preserved_write_scope: <unchanged files; no new owner>
forbidden_scope: <unchanged exclusions>
acceptance_criteria: <only the criterion being repaired plus regression checks>
verification_commands: <exact commands for the repair>
return_contract: Status PASS or BLOCKED with new evidence
```

The original packet, owner, permission boundary, and dependency assumptions remain in force. If the correction is incomplete, conflicts, or fails again, mark the task BLOCKED and escalate to Sol/Main rather than issuing another packet.

## Sol final review

Sol reviews the real diff, resulting artifacts, requirements coverage, and command output. A summary from Luna without inspectable evidence is insufficient.

```yaml
verdict: PASS | PASS_WITH_LIMITATIONS | FAIL
requirements_coverage:
  - criterion: "Acceptance criterion text"
    status: "met | limited | unmet"
    evidence: "Exact diff, artifact, or command result"
findings:
  - "Finding with exact supporting evidence"
required_fixes:
  - "Required fix, or none"
optional_improvements:
  - "Optional improvement, or none"
evidence_quality: "complete | limited | insufficient"
remaining_risks:
  - "Remaining risk, or none"
diff_review:
  scope_ok: true
  files_reviewed: ["exact/output/path"]
artifact_review:
  status: "reviewed | unavailable | not_applicable"
verification:
  - command: "exact command"
    result: "exit status and relevant output"
limitations: []
correction_packet: null
stop_reason: null
```

`PASS` means all required criteria and evidence are complete. `PASS_WITH_LIMITATIONS` records only non-blocking, explicit limitations that Main can communicate or accept. `FAIL` means a required criterion, scope rule, authorization, identity proof, or verification is unmet; it must name the evidence and either produce the single narrow Correction Packet or stop as BLOCKED. Sol arbitrates contradictory Luna returns using the actual evidence and must not merge them mechanically.

## Failure, timeout, and conflict handling

- **Missing or invalid packet:** Luna returns BLOCKED without acting. Sol repairs the packet; Main decides whether the repaired packet is still authorized.
- **Timeout:** record the failure and last evidence, repair the task packet only if the same narrow issue is actionable, and use at most one retry. A timeout is not a PASS.
- **Model or agent unavailable:** Fail Closed. Report the exact missing proof. Continue only after an explicitly authorized choice has a new, observable proof; never silently substitute or spoof identity.
- **Scope drift or dirty worktree:** stop the affected task, preserve unrelated user changes, and compare the final diff only against the exclusive write scope.
- **Writer conflict:** do not run concurrent writers on the same file. Pause the wave, let Sol arbitrate from evidence, and assign one owner before resuming.
- **Contradictory returns:** do not merge mechanically. Sol compares commands, exit status, diffs, and artifacts; evidence decides. Unresolved contradiction is FAIL/BLOCKED.
- **Requirement omission:** a passing test does not erase an unmet acceptance criterion. Sol marks FAIL and names the narrow required correction.

## Red flags and rationalizations

Stop when any of these arguments appears:

- “The label says Luna, so the runtime identity is obvious.” Prove the selected agent, model, effort, and boundary.
- “The change is tiny; we can skip the packet.” Use Level 0 or provide a complete packet; do not use an incomplete handoff.
- “Two workers can edit the shared file and we will reconcile it later.” Give the file one writer.
- “The report says PASS, so review is unnecessary.” PASS without command-level evidence is BLOCKED.
- “Retry until the test turns green.” Issue at most one Correction Packet for one narrow, evidenced issue.
- “The fallback model is close enough.” Fail Closed unless the exact authorized selection is proved.
- “The tests pass, therefore every requirement passed.” Check each acceptance criterion and the real diff.
- “Nested routing is probably available.” Native Nested requires a live proof with effective depth >=2.

## Long-task recoverable state

For work that spans waves or sessions, Main records recoverable state after graph creation, after each wave, before and after any write, and after review. The state must be sufficient to resume without guessing:

```yaml
recoverable_state:
  task_id: "stable parent ID"
  mode: "Compatibility | Native Nested"
  phase: "planned | executing | reviewing | blocked | complete"
  execution_graph_digest: "stable reference to the approved graph"
  completed_tasks: []
  in_flight_tasks: []
  pending_tasks: []
  write_owners: []
  evidence_refs: []
  last_checkpoint: "timestamp or monotonic checkpoint"
  retry_used: false
  next_action: "specific authorized action or stop"
```

Completed evidence is retained; in-flight work is never silently marked complete. A resumed run rechecks selection, permission, scope, and dependency prerequisites before acting. If state is missing or contradictory, stop and return BLOCKED for Main to resolve.
