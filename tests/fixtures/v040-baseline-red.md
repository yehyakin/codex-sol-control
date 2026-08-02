# v0.4 reliability baseline (RED)

Date: 2026-08-03

Scope: anonymous contract, README, benchmark, and forward-fixture assertions for
final-candidate evidence binding, transport completion, no-delta retries,
long-task resume, and conditioned cost wording.

## Command

```sh
/opt/homebrew/bin/python3.13 -m unittest tests.test_contract tests.test_readme tests.test_benchmark -v
```

Exit code: `1`.

## Result

`Ran 41 tests`; `10 failures` and `1 error`.

The failures were expected because the v0.3 production contract did not yet
define the four reliability cases, final-candidate evidence binding, the
release-time runtime matrix, or the conditioned 65% cost fields and wording.
The error was the absent reliability-gated benchmark metric, not an import or
fixture parsing failure.

No runtime identity or private project detail is recorded in this baseline.
