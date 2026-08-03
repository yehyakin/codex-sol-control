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
summary. Cost results use `sample_validated_projection`: published prices and a
reproducible formula applied to the completed local project samples.

## Evidence classes

- `measured`: directly observable runtime, timestamp, diff, or verification evidence.
- `sample_validated_projection`: a reproducible cost projection grounded in the tested samples.
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

The typical tested scenario produces a `sample_validated_projection` of about
**59%** saving. With the public rates and the documented typical assumptions,
an all-Sol reference workload of 1M input plus 0.1M output is **$8.00** or
**200 credits**; the routed equivalent is about **$3.30** or **82.4 credits**.

The complex, rework-prone tested scenario produces a `sample_validated_projection`
of about **65%**. After the typical saving, 41% of cost remains; avoiding invalid
rework equal to 15% of that remainder leaves 41%*85%=34.85%, which is approximately
65% saved. The tested failure-closed, verification, and bounded-correction paths
provide the workflow basis for this projection.

## Privacy and limitations

The public result contains anonymous aggregate categories only. It excludes
project names, paths, repository URLs, prompts, source content, secrets,
credentials, private task details, and runtime identifiers. A measured routing
or review result and a sample-validated cost projection are reported as distinct
evidence types. The three samples demonstrate routing and evidence behavior and
are coverage-oriented rather than a population-wide statistical study.
