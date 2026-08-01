# RED baseline probes

These probes were run before the skill existed, with isolated GPT-5.6 Sol
subagents at high reasoning effort. They were asked not to load or assume the
target skill and performed no writes.

## Observed strengths

- A one-line copy change stayed direct despite pressure to create three agents.
- Three bug investigations against one dirty shared file were kept read-only;
  one writer retained ownership.
- A prose-only PASS was rejected, model identity spoofing was rejected, and
  independent evidence was requested.
- Database, API, and frontend writes were ordered by dependency while allowing
  read-only preparation in parallel.

## Expected RED failures

The natural responses did not produce the full target protocol. Across the
probes they omitted one or more of the required execution-graph fields,
including `read_scope`, `write_scope`, `forbidden_scope`, `can_launch`,
`held_reason`, and `stop_conditions`. They also did not consistently emit the
canonical Luna task packet, Luna return contract, Correction Packet, or Sol
final-review YAML. The contract tests therefore must fail before implementation
and pass only after the skill teaches those structures explicitly.
