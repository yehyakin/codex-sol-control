# v0.2.0 RED baseline

Date: 2026-08-01

Repository baseline: `1350ceae58eec3c55a8139488a799518a5d437bb`

The repository currently contains the v0.1 package. This fixture records the
intended RED boundary for the tests-first migration; it is not a production
implementation and it does not grant permission to edit the legacy targets.

## Target contract

- The public skill is named `sol-luna` and is invoked explicitly with
  `$sol-luna`.
- Ordinary simple work outside the explicit skill remains direct. A plan-only
  request invokes Sol and may use zero Luna workers.
- Sol emits only `goal`, `done_when`, `tasks`, and `stages` as its plan shape.
- Every Luna task has `Task ID`, `Task`, `Write scope`, optional `Context`,
  `Do not touch`, `Expected result`, and `Verification`.
- Every Luna result has `Task ID`, `Status: PASS | BLOCKED`, `Summary`,
  `Changed`, `Verification`, `Evidence`, and `Blocker`.
- Sol review uses `PASS | FIX | BLOCKED` and permits at most one focused fix.
- Exact model/reasoning-effort proof, inherited permissions, and Fail Closed
  remain runtime requirements; runtime mechanics stay in `runtime-notes.md`.
- One file has one owner, shared integration files have one Luna owner, and
  batching follows live capacity rather than a fixed worker count.

## Observed RED run against v0.1

Command: `/opt/homebrew/bin/python3.13 -m unittest discover -s tests -v`

Result: exit `1`, 21 tests run, 14 assertion failures, 0 errors. The passing
checks were fixture shape, generic contamination, config byte integrity,
rollback preservation, modified shared-target refusal, shell parsing, and the
legacy validator smoke check.

Representative failures were:

- `test_required_v020_files_exist` for the missing runtime note and v0.2
  target files;
- `test_public_skill_is_named_and_explicitly_invoked` for the old skill name;
- `test_luna_task_packet_uses_the_simplified_fields` and
  `test_luna_result_and_sol_review_contracts_are_falsifiable` for absent v0.2
  packet/result contracts;
- `test_install_creates_v020_targets_and_versioned_state` for the old install
  paths;
- `test_install_preserves_modified_legacy_targets` for the v0.1 installer
  refusing a checksum-mismatched legacy target;
- `test_lifecycle_scripts_encode_v020_paths_and_legacy_migration` for missing
  v0.2 lifecycle paths.

No import, parsing, or temporary-root setup errors occurred.

## Intended RED failures against v0.1

The current v0.1 production files should fail only through ordinary test
assertions for missing v0.2 behavior, including:

- missing `.agents/skills/sol-luna` and `sol-controller.toml` targets;
- the old public skill name and old Sol plan/task packet shapes;
- absent v0.2 routing and result/review language;
- installers that still create only `orchestrate-sol-luna` and
  `sol-planner.toml` rather than migrating safely;
- uninstall and restore operations that do not own the v0.2 target paths.

The migration tests additionally require checksum-aware handling of unmodified
v0.1 targets, preservation of modified legacy targets, transactional rollback,
unrelated-file preservation, and byte-for-byte `config.toml` integrity.
