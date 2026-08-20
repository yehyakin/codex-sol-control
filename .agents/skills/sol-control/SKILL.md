---
name: sol-control
description: Use only when the user explicitly invokes the legacy $sol-control command; redirect that request to the canonical $codex-prove workflow during the v1.0 compatibility window.
---

# Sol Control compatibility entry

This is a temporary explicit-only compatibility entry for Codex PROVE v1.0.

Load and follow the complete canonical Skill at
`../codex-prove/SKILL.md`, including its references, role profiles, runtime
proof, ownership, verification, and review gates. Treat the user's invocation as
if it were `$codex-prove`. Do not run or reconstruct the old Sol-specific
workflow. If the canonical Skill or its configured agents cannot be loaded,
return `BLOCKED` instead of weakening the protocol.

Tell the user once that `$sol-control` is deprecated and `$codex-prove` is the
new command. Do not invoke this compatibility entry implicitly.
