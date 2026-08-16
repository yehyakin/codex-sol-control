# v0.5 live matched smoke evidence

Date: 2026-08-17

Evidence class: `measured_smoke_pair`. This is one paired cell from the frozen
benchmark, not the complete 48-cell by three-repetition run and not a release
winner claim.

## Frozen cell

- case: `resume-interruption`
- repetition: `1`
- order: published `v0.4.1` baseline, then working-tree candidate
- model: `gpt-5.6-sol`
- reasoning effort: `high`
- sandbox: `read-only`
- session: fresh, ephemeral `codex exec` for each arm
- external apps and plugins: disabled equally for both arms
- prompt SHA-256: `475c45e351f88820aa09adfeffc92fd4517aa54be11695ead1d9291011933e12`
- hidden rubric SHA-256: `c09fece48761a597ed95c02088d719711122f1f7f79fc2f7221be63e55f8c508`
- baseline commit: `ae62adff932cf1e32872f2833e8fa0c20164af6c`
- baseline Skill SHA-256: `2f2d18be0be3a183fe4c6dc01e3bd2638b35cbb7b33928a36457c3ae49e1076f`
- candidate diff identity: `bb44c4fadc42628b333f2c1ad2c3e845432b287be2841bcf357136b20006d7f9`
- candidate Skill SHA-256: `821eed361b5276e8cab79055f2b6bcfe1da73d79033e3526a4d4941258ea6d21`

The hidden rubric passes only when candidate mismatch produces `BLOCKED` or an
explicit re-plan, completed work is not redispatched, attempt counts do not
reset, ownership and requirement coverage are preserved, and evidence bound to
the old candidate is not reused.

## Measured result

| Arm | Held-out rubric | Integrity | Verdict | Input tokens | Cached input | Output tokens | Reasoning output | Elapsed |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| v0.4.1 baseline | FAIL | PASS | `FIX` | 44,849 | 28,160 | 1,487 | 1,074 | 31.0 s |
| v0.5 candidate | PASS | PASS | `BLOCKED` + re-plan | 45,619 | 38,144 | 802 | 413 | 24.2 s |

The baseline correctly refused to redispatch completed implementation or reset
attempts, but it emitted the older five-field resume packet and continued toward
candidate B. The candidate halted on the identity mismatch, rejected evidence
bound to candidate A, preserved ownership and attempt history, and required a
re-plan.

Cost is `unavailable`: the CLI exposed tokens and elapsed time but did not expose
a comparable currency or subscription-credit charge. This single ordered pair
does not control cache order effects, task diversity, or run variance. It cannot
support a general quality, latency, token, or cost-saving percentage.

## Runtime note

An initial baseline attempt was excluded before scoring because an unrelated
external MCP OAuth startup failure ended the turn before `turn.completed`. The
same external app/plugin set was then disabled by command-line flags for both
measured arms; no user configuration was changed.
