# Sol Luna README Visual Redesign Design

**Date:** 2026-08-03
**Status:** Approved
**Scope:** `README.md`, `README.en.md`, README contract tests, and repository-owned README artwork

## Goal

Turn the bilingual README into a mature, scannable open-source project homepage
without weakening the project's technical evidence. The page must explain one idea
immediately: Sol is the single controller that plans, assigns, and reviews; Luna Max
workers execute bounded tasks and return verification evidence.

The visual direction is an original **Sol architect + Luna workshop** world. It may
learn general presentation techniques from
[`oil-oil/oil-visual`](https://github.com/oil-oil/oil-visual), including a wide hero,
ink linework, halftone texture, restrained accent colors, and short diagram labels.
It must not copy that project's characters, dog, artwork, wording, logo, or distinctive
composition.

## Required first-screen message

The Chinese README remains the default entry. Its first screen must communicate:

- **普通任务约节省 59%**;
- **复杂且容易返工任务在估算条件下约节省 65%**;
- both figures are estimates rather than measured guarantees;
- the 59% scenario applies to work suitable for bounded delegation;
- simple Direct tasks use zero delegation and claim 0% routing saving;
- a minimal validation and installation path.

The English README must carry the same facts, order, numbers, commands, image sequence,
and evidence boundaries in natural English.

## Information architecture

Use this exact reading order in both README files:

1. Language switcher
2. Wide hero illustration
3. Project name, one-sentence positioning, and compact metadata
4. Two cost cards: typical 59% and conditional complex-task 65%
5. Adjacent estimate, Direct 0%, and non-guarantee disclaimer
6. 60-second quickstart
7. One controller, one execution workshop
8. Route selection: Direct / Sol-only / Sol to Luna
9. Workflow: plan, execute, self-check, Sol review
10. Reliability through identity, ownership, evidence, and bounded correction
11. Real-project routing samples, explicitly not a measured cost benchmark
12. Cost model and evidence boundaries
13. Platforms, installation lifecycle, backup, and rollback
14. Repository development and verification
15. Limitations
16. Prior art, license, and acknowledgements

The first screen stays concise. Full pricing tables, formula derivations, Windows Server
versus native Windows 11 evidence, result-packet fields, rollback internals, and the
complete benchmark table move lower in the document or into clearly named `<details>`
blocks. Existing supporting documents remain linked.

## Original artwork system

Create four self-contained, repository-owned SVG illustrations:

### 1. Hero

- **File:** `docs/assets/sol-luna-hero.svg`
- **Canvas:** 1440 x 480, 3:1
- **Scene:** A central blueprint table anchors the composition. Sol issues bounded work
  orders to several distinct Luna workbenches. Evidence packets return to Sol along an
  upper inspection rail.
- **Message:** One controller, bounded execution, evidence returning for review.

### 2. Architecture

- **File:** `docs/assets/sol-luna-architecture.svg`
- **Canvas:** 1440 x 810, 16:9
- **Scene:** A building-section diagram with the Sol planning room above, separate Luna
  workstations below, and a return inspection lift.
- **Message:** Parallel execution is allowed only across non-overlapping ownership.

### 3. Routing

- **File:** `docs/assets/sol-luna-routing.svg`
- **Canvas:** 1200 x 720, 5:3
- **Scene:** Incoming work reaches a routing table. Simple tasks use a short Direct track;
  planning-only work stops at Sol; bounded implementation enters the Luna workshop.
- **Message:** The Skill does not delegate everything.

### 4. Review

- **File:** `docs/assets/sol-luna-review.svg`
- **Canvas:** 1200 x 720, 5:3
- **Scene:** Luna delivers evidence trays labelled `FILES`, `DIFF`, and `TEST` to Sol's
  inspection lightbox. The only exit stamps are `PASS`, `FIX`, and `BLOCKED`.
- **Message:** Worker completion is not final approval; Sol reviews real artifacts.

### Shared visual language

- warm paper `#F4E8D3`;
- ink `#17130F`;
- Sol burnt orange `#D95F32`;
- Luna moon blue `#416C8A`;
- no gradients; dotted halftone patterns provide gray and shadow;
- strong black frames, slightly irregular ink strokes, and at most five short labels per
  illustration;
- Sol is represented through blueprint, square, ruler, and review-stamp language;
- Luna is represented through moon-phase badges, bounded work cells, tools, and evidence
  trays;
- no glasses mascot, pet, external font, external resource, script, tracking, embedded
  bitmap, or copied reference asset;
- each SVG has a meaningful `<title>`, `<desc>`, and `viewBox`.

## Content preservation and reduction

Keep these facts intact:

- the canonical repository URL;
- Sol and Luna exact runtime identities and fail-closed behavior;
- one file, one owner;
- live-capacity stages rather than a promised fixed worker maximum;
- evidence freshness and real-diff review;
- at most one same-owner, same-scope focused correction;
- long-task-only resume packets;
- macOS, Linux, and Windows lifecycle commands;
- Windows Server evidence is not native Windows 11 evidence;
- the price snapshot, formula inputs, 59%, 65%, 34.85%, and measured/estimated/unavailable
  distinctions;
- repository layout, validation commands, limitations, prior art, Apache-2.0 license, and
  LINUX DO acknowledgement.

Remove repetition rather than evidence. The README should explain each contract once and
link to the Skill reference, runtime surface matrix, or benchmark document for the full
operating detail.

## Cost-language guardrails

- Do not imply that every ordinary task saves 59%. State that the headline is a typical
  estimate for tasks suitable for bounded delegation.
- Keep Direct at zero delegation and 0% routing saving.
- Keep 65% conditional: after the typical estimate leaves 41% cost, avoiding invalid
  rework equal to 15% of that remainder leaves `41% * 85% = 34.85%`, or about 65% saved.
- Superseded evidence label: present 65% as a sample-validated projection.
- Keep the 96% worker-token segment comparison out of the hero; it is not a whole-task
  promise.
- Describe existing real-project evidence as routing samples, not a measured cost proof.

## Bilingual parity

- One owner updates both README files in the same task.
- Heading order, image order, image paths, commands, model names, formulas, numbers,
  evidence classifications, and links stay aligned.
- Alt text is localized rather than copied.
- English prose is a semantic peer and must not introduce a stronger marketing claim.
- Tests compare the stable structural and factual signals across both documents.

## Validation design

Update `tests/test_readme.py` before implementation so the new contract fails for only the
missing structure or artwork. It must verify:

- Chinese-first and cost-first placement;
- the 59%, conditional 65%, 34.85%, Direct 0%, and estimate boundaries;
- matching bilingual heading and image-target sequences;
- all four local SVG paths in the intended order;
- localized, non-empty image alt text;
- meaningful SVG `<title>`, `<desc>`, and `viewBox`;
- pure vector files with no external URL, embedded bitmap, script, gradient, or copied
  reference term;
- all existing repository, platform, lifecycle, benchmark, and pricing contracts.

Final verification includes targeted README and benchmark tests, the complete repository
test suite, `scripts/validate.sh`, `git diff --check`, local link checks, SVG rendering at
desktop/tablet/mobile widths, and Sol review of the actual files and diff.

## Final acknowledgement

Both README files end with the matching bilingual acknowledgement. The Chinese default
README uses the exact approved wording:

**致谢 / Thanks**

感谢 [LINUX DO 论坛](https://linux.do/) 社区的关注、反馈与支持

The English peer keeps the same heading and link with an equivalent English sentence.

## Scope boundary

This redesign changes documentation, artwork, and documentation tests only. It does not
change the Skill runtime contract, agent TOML files, lifecycle scripts, global installation,
or any other project.
