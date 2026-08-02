# Chinese-First README and Real-Project Benchmark Design

Date: 2026-08-02

Repository: `yehyakin/codex-sol-luna`

Baseline: `main@22c0773`

## Goal

Make Simplified Chinese the canonical GitHub README language, move the cost
benefit into the first screen with the exact Chinese headline
`成本约节省 59%`, and use existing local Sol Luna project runs as evidence for
an anonymized, read-only benchmark.

The design keeps the product core unchanged: Sol is the single controller that
understands, plans, assigns, schedules, and reviews; Luna Max executes bounded
tasks and returns verification evidence.

## Confirmed decisions

1. `README.md` becomes the complete Simplified Chinese guide.
2. The current English guide moves to `README.en.md`.
3. Both files retain a visible language switch at the top.
4. The first screen uses the exact headline `成本约节省 59%`.
5. The headline remains an estimate. The same screen states the conservative
   estimate of about 38%, the execution-heavy estimate of about 74%, and that
   the figures are not a guarantee for every task.
6. Real-project evidence uses the two-stage approach selected by the user:
   reuse existing evidence first, then run only the minimum read-only probes
   needed to close material gaps.
7. Public benchmark data is anonymous. It uses project categories rather than
   project names and excludes paths, business content, source text, secrets,
   credentials, and private task descriptions.

## README information architecture

The canonical Chinese README uses this order:

1. Language switch, title, and one-sentence Sol/Luna positioning.
2. First-screen cost card headed `成本约节省 59%`.
3. Three-step architecture: Sol plans and assigns, Luna Max executes and
   verifies, Sol reviews real files, diffs, and evidence.
4. When to use the Skill and when to stay direct.
5. Quickstart for macOS, Linux, and Windows.
6. Reliability boundaries: dynamic capacity, one file/one owner, evidence
   gates, bounded correction, and exact-model Fail Closed behavior.
7. Real-project benchmark summary.
8. Detailed pricing snapshot, formula, assumptions, and disclaimers.
9. Engineering reference: lifecycle, validation, platform evidence,
   limitations, prior art, and license.

The architecture illustrations remain in the README, but the cost conclusion
appears before the architecture section. The detailed pricing tables remain in
the later cost section so the first screen stays readable.

The English README mirrors the same facts and section order. Its headline is a
faithful English equivalent, not a different claim.

## Cost-claim contract

The 59% figure remains the current typical-scenario estimate:

```text
savings = delegated_share * (1 - luna_duplication / 25) - sol_overhead
```

The current typical assumptions are 70% delegated work, 115% Luna token
duplication relative to that delegated baseline, and 8% added Sol planning and
review overhead. The headline must not imply that every task saves 59%.

The README must keep these distinctions explicit:

- the otherwise equivalent Luna worker-token segment is about 96% cheaper at
  the dated price snapshot;
- whole-task savings are lower because Sol still plans and reviews;
- Direct tasks claim 0% routing savings;
- measured benchmark values, modeled estimates, and unavailable measurements
  are separate evidence classes;
- retries, repeated context, poor decomposition, or heavy review can reduce or
  erase savings.

If the real-project evidence does not contain exact per-model token or credit
usage, it must not be presented as an exact measured cost reduction. The 59%
headline stays labeled as an estimate until comparable usage proves otherwise.

## Real-project benchmark architecture

### Stage 1: reuse existing evidence

Inspect existing completed Sol Luna task records and the minimum corresponding
read-only repository evidence. Accept a result only when the available record
can be reconciled with observable task state, real diffs or changed-path
evidence, and verification output. A worker or thread summary alone is not
proof of completion.

Collect, when available:

- expected and observed route: Direct, Sol-only, or Sol to Luna;
- number of Luna workers and execution waves;
- whether writable scopes were disjoint and every shared file had one owner;
- Luna verification evidence and exact task status;
- Sol final review, missed criteria, corrections, and blockers;
- elapsed time from trustworthy task timestamps;
- exact model identity and reasoning effort when observable;
- exact per-model tokens or credits only when the runtime exposes them.

### Privacy gate

Before any evidence enters the public repository, convert it to anonymous
categories such as `codebase`, `documentation`, and `infrastructure`. Remove
project names, absolute paths, repository URLs, business terminology, source
snippets, prompts, user data, secrets, credentials, and unique identifiers.

Raw local evidence is not committed. The public repository contains only the
method and sanitized aggregate results.

### Stage 2: controlled read-only gap probes

Run a new probe only when Stage 1 cannot support a material conclusion. Use the
minimum sufficient probes across at least three distinct project categories.
Each probe must:

- be read-only in the business repository;
- use the installed exact Sol/high and Luna/max identities or fail closed;
- define the same bounded objective and observable result for any comparison;
- avoid deployment, accounts, credentials, production, deletion, or external
  side effects;
- stop when exact identity, comparable scope, or verification cannot be proved;
- record the result as unavailable rather than infer a number from prose.

No business repository receives benchmark files, commits, configuration
changes, or generated artifacts.

## Public benchmark artifacts

Add two small public artifacts outside the runtime Skill context:

- `tests/real-project-benchmark.md`: methodology, evidence classes, sanitized
  aggregate results, limitations, and run date.
- `tests/fixtures/real-project-benchmark.json`: machine-checkable anonymous
  aggregate data. Numeric fields may be `null` when evidence is unavailable,
  but each such field must include an evidence status.

Extend repository tests to enforce:

- at least three anonymous project categories;
- no absolute local paths or known private project names;
- only `measured`, `estimated`, or `unavailable` evidence labels;
- no exact cost claim when the required token or credit evidence is absent;
- parity between the Chinese and English README benchmark facts;
- the Chinese README remains the canonical `README.md`;
- the first cost headline contains `成本约节省 59%` before the architecture
  heading.

No general dashboard, database, telemetry service, permanent task ledger, or
benchmark framework is introduced.

## Failure handling

- Missing or contradictory existing evidence is `unavailable`, not a guessed
  measurement.
- A requested probe that could write to a business repository is rejected.
- A probe that cannot prove exact model, effort, or permission identity fails
  closed.
- Non-comparable all-Sol and Sol/Luna scopes are excluded from cost comparison.
- Sensitive or uniquely identifying evidence is removed before publication;
  if it cannot be safely anonymized, the sample is excluded.
- One failed category does not block other safe categories, but the README must
  report the resulting limitation.

## Validation and acceptance

Implementation is accepted when:

1. `README.md` is the complete Chinese guide and `README.en.md` is the complete
   English peer.
2. Both language switches resolve and no repository link still expects
   `README.zh-CN.md`.
3. The first screen contains `成本约节省 59%` before the architecture section,
   with its estimate boundary visible nearby.
4. Existing architecture, safety, Windows, pricing, prior-art, and license facts
   remain consistent across both languages.
5. The benchmark includes at least three anonymous project categories without
   modifying any business repository.
6. Every public benchmark metric declares `measured`, `estimated`, or
   `unavailable` evidence status.
7. No private project name, absolute local path, prompt, source content,
   credential, token, or secret appears in committed benchmark data.
8. The full unit suite, standalone validator, Skill Creator validator, Markdown
   links, YAML, TOML, shell checks, PowerShell structure checks, Git whitespace,
   and Windows CI pass.
9. The installed Skill and agent TOMLs remain byte-identical to repository
   source after any required installation sync.
10. GitHub `main` matches the verified local commit.

## Non-goals

- No change to the Sol/Luna role model or routing protocol.
- No additional agent roles, fixed worker count, dashboard, or heavy ledger.
- No mutation of business projects for benchmark purposes.
- No claim that the estimate is an empirical guarantee.
- No release tag or package publication unless separately requested.
