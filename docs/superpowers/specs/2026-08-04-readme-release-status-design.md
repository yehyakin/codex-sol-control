# README Release Status Design

Date: 2026-08-04

## Goal

Update the bilingual README so a visitor can see the verified v0.3.0 release
status without reading the implementation report or mistaking configuration
claims for runtime evidence. After the README update passes the repository
checks, merge the complete `codex/terra-tiered-routing` branch into `main` and
push the merge.

## Scope

Modify only `README.md`, `README.en.md`, and the tests needed to enforce their
parity. Do not redesign the existing Control Orbit artwork, change the routing
contract, alter cost projections, change installation files, or claim native
Windows 11 or Native Nested verification.

The already approved implementation-report and design documents remain part of
the branch and will be included in the final merge.

## Content design

Add one compact release-status block after the canonical repository/invocation
paragraph and before the Control Orbit architecture image. This location keeps
the first screen cost-first, while making evidence visible before the detailed
architecture.

The Chinese and English blocks must communicate the same facts:

- release candidate version: v0.3.0;
- local repository verification: Skill Creator PASS and 106/106 tests PASS;
- hosted platform verification: POSIX PASS and Windows Server 2022 plus
  `windows-latest`, each under Windows PowerShell 5.1 and PowerShell 7, PASS;
- verified orchestration path: Compatibility;
- unclaimed surfaces: Native Nested, fresh-CLI exact child model/effort identity,
  and physical Windows 11;
- a repository-relative link to
  `ORCHESTRATE_SOL_LUNA_V2_IMPLEMENTATION_REPORT.md`;
- links to the green POSIX and Windows GitHub Actions runs for report commit
  `6895f06`.

Use a short heading and a compact table or bullet group. Do not add screenshots,
new hero claims, marketing superlatives, or another cost disclaimer.

## Evidence update rule

The README must point to the already green release-candidate runs for report
commit `6895f06`. The final README commit must then pass the same workflows
before merge. Therefore the implementation sequence is:

1. add the bilingual status block and parity tests;
2. run local validation;
3. commit and push the feature branch;
4. wait for the POSIX and Windows workflows on that exact README commit;
5. merge only when those final checks are green.

This avoids an endless self-referential documentation loop: the published links
are stable evidence for `6895f06`, while branch protection and the merge audit
record the final README commit's separate green checks. The status text must
state that the linked matrix is bound to `6895f06`.

## Validation

Required before merge:

- `bash scripts/test.sh` passes all tests;
- `bash scripts/validate.sh` passes;
- `git diff --check` passes;
- README parity tests prove both languages contain the same version, test count,
  Compatibility/Native Nested boundary, report link, evidence commit, and CI run
  links;
- the final README commit has successful POSIX and Windows workflows;
- `git merge-tree --write-tree origin/main HEAD` reports no conflict;
- the merged `main` result passes `bash scripts/test.sh` and
  `bash scripts/validate.sh` before it is pushed.

## Delivery

Use a normal merge commit so the release branch history and its bounded Windows
correction remain auditable. Push `main` only after post-merge verification.
Preserve the feature branch on the remote; deleting it is outside this update.
