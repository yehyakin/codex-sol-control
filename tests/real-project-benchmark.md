# Anonymous real-project benchmark

Date: 2026-08-02

## Method

Existing completed evidence was inspected first. New probes were allowed only
for material gaps and were read-only. The existing records covered the three
required routing categories, so no additional model probe was needed and no
business repository was modified.

Runtime activity, completed-task timestamps, verification-bearing results, and
final review states were accepted as `measured`. A value that could not be
proved from those records remained `unavailable`; it was not inferred from a
summary. The published 59% cost figure remains `estimated` because comparable
exact per-model usage was not exposed.

## Evidence classes

- `measured`: directly observable runtime, timestamp, diff, or verification evidence.
- `estimated`: calculated from published assumptions rather than exact task usage.
- `unavailable`: evidence was insufficient, incomparable, or not exposed.

## Anonymous categories

| Category | Route | Luna workers | Waves | Verification | Final review | Elapsed |
| --- | --- | ---: | ---: | --- | --- | ---: |
| Codebase | `sol_then_luna` (`measured`) | `unavailable` | `unavailable` | evidence present (`measured`) | `BLOCKED` (`measured`) | 2340 s (`measured`) |
| Documentation | `sol_then_luna` (`measured`) | `unavailable` | `unavailable` | evidence present (`measured`) | `PASS` (`measured`) | 379 s (`measured`) |
| Infrastructure | `direct` (`measured`) | 0 (`measured`) | 0 (`measured`) | evidence present (`measured`) | not applicable (`measured`) | 859 s (`measured`) |

The codebase sample is a useful failure-path result: Sol-controlled execution
did not convert an unresolved condition into a false success. The documentation
sample reached `PASS` with verification evidence. The infrastructure sample
remained Direct and created zero Luna work, demonstrating that the benchmark
does not assume every real task should be delegated.

## Cost result

The current headline remains an `estimated` 59%. An exact `measured` workflow
saving is `unavailable` because comparable exact per-model token or credit usage
was not exposed in these records. Observing routing, verification, or review
does not justify inventing the missing cost measurement.

A separate reliability-gated complex-task estimate is about **65%**, not measured.
After the typical saving, 41% of cost remains; avoiding invalid rework equal to 15%
of that remainder leaves 41%*85%=34.85%, which is approximately 65% saved. This
conditional reliability case is separate from any execution-heavy scenario.

## Privacy and limitations

The public result contains anonymous aggregate categories only. It excludes
project names, paths, repository URLs, prompts, source content, secrets,
credentials, private task details, and runtime identifiers. A measured routing
or review result does not turn an unavailable cost metric into a measured
saving. The three samples demonstrate routing and evidence behavior; they are
not a statistically representative performance benchmark.
