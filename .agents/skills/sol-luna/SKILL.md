---
name: sol-luna
description: Use only when the user explicitly invokes the legacy $sol-luna name while migrating to $sol-control.
---

# Sol Luna compatibility alias

`$sol-luna` is the one-release compatibility entry for `$sol-control`.

Immediately read `../sol-control/SKILL.md` and follow it exactly. Do not create
a second workflow, relax any evidence gate, change model routing, or trigger
implicitly. Tell the user once that `$sol-control` is the canonical invocation.

The alias remains available through v0.4.x and is scheduled for removal in
v0.5.0. New documentation and automation must use `$sol-control`.
