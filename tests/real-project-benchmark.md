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
summary. Cost results use `scenario_model_projection`: official rates and a
reproducible formula for declared routing scenarios, not completed local samples.

## Evidence classes

- `measured`: directly observable runtime, timestamp, diff, or verification evidence.
- `scenario_model_projection`: a reproducible budget projection from official rates and declared scenario shares.
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

## Current cost result

The current public model uses relative subscription-credit weights rather than
claiming a measured A/B saving: Sol = **1**, Terra High = **0.4**, and Luna Max
= **0.04**. API dollars and subscription credits are separate accounting units;
the exact API and credit rows remain documented in the bilingual README.

The scenario/model projection is published as ranges, not as a single direct
task promise:

- ordinary bounded work: **72%-76%**;
- mixed Sol/Terra/Luna routing: **50%-60%**;
- complex work kept Direct: **33%-43%**;
- composite center: approximately **56%**.

These are scenario/model projections from official rates and declared routing assumptions,
not a newly measured matched A/B experiment. No complex **65%** direct
saving or Luna=Sol **1/25** ratio is treated as the current public contract.

## Privacy and limitations

The public result contains anonymous aggregate categories only. It excludes
project names, paths, repository URLs, prompts, source content, secrets,
credentials, private task details, and runtime identifiers. A measured routing
or review result and a scenario/model cost projection are reported as distinct
evidence types. The three samples demonstrate routing and evidence behavior and
are coverage-oriented rather than a population-wide statistical study.
