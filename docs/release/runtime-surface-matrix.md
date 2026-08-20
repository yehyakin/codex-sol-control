# Runtime surface matrix

Release-time evidence for Codex PROVE. Configuration, an agent label, or a child
self-report is not runtime proof. Statuses are `VERIFIED`, `FAILED`, or
`UNVERIFIED`.

Candidate date: 2026-08-20

## v1.0 model-neutral roles

| Surface | Signal | Status | Evidence location | Date |
| --- | --- | --- | --- | --- |
| Desktop | `prove-controller` selection | UNVERIFIED | Requires fresh-session Host launch proof after v1.0 installation | 2026-08-20 |
| Desktop | `prove-complex-worker` selection | UNVERIFIED | Requires fresh-session Host launch proof after v1.0 installation | 2026-08-20 |
| Desktop | `prove-efficient-worker` selection | UNVERIFIED | Requires fresh-session Host launch proof after v1.0 installation | 2026-08-20 |
| Desktop | exact models and reasoning | UNVERIFIED | TOML is candidate configuration, not runtime proof | 2026-08-20 |
| Desktop | Native Nested | UNVERIFIED | Requires a real controller-to-worker launch with the new role names | 2026-08-20 |
| Desktop | Compatibility | UNVERIFIED | Requires Host dispatch plus final review with the new role names | 2026-08-20 |
| Desktop | fresh-session Skill discovery | UNVERIFIED | Requires `$codex-prove` discovery and `$sol-control` compatibility check | 2026-08-20 |
| Windows CI | install/upgrade/rollback/uninstall | UNVERIFIED | Pending v1.0 Windows workflow on Windows Server 2022 and `windows-latest` | 2026-08-20 |
| Physical Windows 11 | Native Nested | UNVERIFIED | No v1.0 physical-device runtime payload captured | 2026-08-20 |

Update this table only from actual launch, result, lifecycle, or CI evidence.

## Retained v0.5 historical evidence

The previous model-branded release verified the following on 2026-08-17:

- Desktop Host/tool mapping selected `sol-controller`, `terra-high-worker`, and
  `luna-max-worker` with `fork_turns="none"` and the configured model/effort.
- `sol-controller` launched two independent Terra audits, one bounded Luna
  smoke, and one qualifying read-only challenge.
- Host-owned baseline/final snapshots bound changed paths and artifacts before
  the final review.
- A separate `codex exec` Native Nested path proved Sol-to-Luna dispatch and a
  structured worker result.

This evidence supports continuity of the protocol, but it does not prove the new
`prove-*` agent names. The v1.0 release must capture a fresh runtime record.

The matched protocol and retained smoke are documented in
[`tests/v100-ab-benchmark.md`](../../tests/v100-ab-benchmark.md) and
[`tests/v100-live-smoke.md`](../../tests/v100-live-smoke.md). The smoke remains a
single historical pair and does not replace the unfinished full benchmark.
