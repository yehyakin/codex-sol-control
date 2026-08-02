# README Control Orbit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the generic workshop README treatment with a bilingual, project-native Sol control-orbit visual system and a shorter cost-first reading order.

**Architecture:** Four deterministic SVG assets share one geometry and palette: localized heroes establish identity and value, while localized control-plane explainers prove routing, ownership, and evidence return. README copy remains searchable Markdown and is only changed after the local visual preview is approved.

**Tech Stack:** GitHub Markdown, hand-authored SVG 1.1, Python `unittest`, `xml.etree.ElementTree`, POSIX shell, PowerShell lifecycle manifests, local browser preview.

---

## File Map

- Create `docs/assets/readme/hero-zh.svg`: Chinese integrated hero.
- Create `docs/assets/readme/hero-en.svg`: English integrated hero with matching geometry.
- Create `docs/assets/readme/control-plane-zh.svg`: Chinese routing and review proof board.
- Create `docs/assets/readme/control-plane-en.svg`: English routing and review proof board.
- Create `tests/test_readme_control_orbit_assets.py`: SVG accessibility, safety, sizing, and localization contract.
- Modify `README.md`: Chinese cost-first reading order and new assets.
- Modify `README.en.md`: English equivalent structure and new assets.
- Modify `tests/test_readme.py`: new image sequence and renamed section sequence.
- Modify `scripts/validate.sh`: require and parse the four new assets.
- Modify `scripts/validate.ps1`: require and parse the four new assets.
- Modify `scripts/install.sh`: include the new README asset directory in the owned install manifest.
- Modify `scripts/install.ps1`: include the new README asset directory in the owned install manifest.
- Modify `tests/test_contract.py`: update the required repository/install surface.
- Modify `tests/test_installers.py`: update installed-file expectations.
- Remove the four superseded `docs/assets/sol-luna-*.svg` files only after preview approval and only after confirming no references remain.
- Create a temporary preview under `/Users/kin3/.codex/visualizations/2026/08/01/019fbd2b-f26c-7c13-929a-f396a14af022/`; do not commit it.

### Task 1: Add the SVG Contract

**Files:**
- Create: `tests/test_readme_control_orbit_assets.py`
- Test: `tests/test_readme_control_orbit_assets.py`

- [ ] **Step 1: Write the failing asset contract**

Create a `unittest` module that defines these exact paths:

```python
ROOT = Path(__file__).resolve().parents[1]
ASSETS = {
    "hero-zh.svg": ROOT / "docs/assets/readme/hero-zh.svg",
    "hero-en.svg": ROOT / "docs/assets/readme/hero-en.svg",
    "control-plane-zh.svg": ROOT / "docs/assets/readme/control-plane-zh.svg",
    "control-plane-en.svg": ROOT / "docs/assets/readme/control-plane-en.svg",
}
```

The test must assert for every asset:

```python
self.assertTrue(path.is_file())
root = ET.parse(path).getroot()
self.assertEqual("svg", root.tag.rsplit("}", 1)[-1])
self.assertEqual("0 0 1200 420" if name.startswith("hero") else "0 0 1200 520", root.attrib["viewBox"])
self.assertIsNotNone(root.find(".//{http://www.w3.org/2000/svg}title"))
self.assertIsNotNone(root.find(".//{http://www.w3.org/2000/svg}desc"))
self.assertNotRegex(source, r"(?is)<script\b|<foreignObject\b|<image\b|https?://|data:image")
```

It must also assert that Chinese assets contain `Sol` and `Luna` plus Chinese text, English assets contain `Sol`, `Luna`, and `estimated`, hero assets contain `59%`, and control-plane assets contain `PASS`, `FIX`, and `BLOCKED`.

- [ ] **Step 2: Run the contract and prove RED**

Run:

```bash
python3 -m unittest tests.test_readme_control_orbit_assets -v
```

Expected: FAIL because all four `docs/assets/readme/*.svg` files are absent.

- [ ] **Step 3: Commit the RED contract**

```bash
git add tests/test_readme_control_orbit_assets.py
git commit -m "test: define control orbit README assets"
```

### Task 2: Build the Localized Control-Orbit Assets

**Files:**
- Create: `docs/assets/readme/hero-zh.svg`
- Create: `docs/assets/readme/hero-en.svg`
- Create: `docs/assets/readme/control-plane-zh.svg`
- Create: `docs/assets/readme/control-plane-en.svg`
- Test: `tests/test_readme_control_orbit_assets.py`

- [ ] **Step 1: Create the Chinese hero**

Use a `1200 × 420` canvas with a full `#0B1020` background and include:

```text
SOL / LUNA
Sol 主控 · Luna Max 执行
普通任务约节省 59%
基于典型路由假设 · 估算，非保证
PLAN → EXECUTE → REVIEW
FILES · DIFF · TEST
```

Place the title and cost statement in the left 54% of the canvas. Place one
orange Sol core above three teal Luna nodes in the right 46%. Draw solid orange
outbound task paths and dotted periwinkle inbound evidence paths. Keep every
required label at `20` SVG units or larger.

- [ ] **Step 2: Create the English hero**

Reuse geometry, colors, and semantic group IDs from the Chinese hero, fitting
these strings independently:

```text
SOL / LUNA
Sol controls · Luna Max executes
~59% estimated savings
Typical suitable routing · estimate, not a guarantee
PLAN → EXECUTE → REVIEW
FILES · DIFF · TEST
```

- [ ] **Step 3: Create the Chinese control-plane explainer**

Use a `1200 × 520` canvas with three horizontal lanes:

```text
DIRECT      当前 Codex 直接完成                  零委派
SOL-ONLY    计划 / 判断 / 审核                   无 Luna
SOL → LUNA  有界任务 → 独立 Owner → 证据返回      PASS / FIX / BLOCKED
```

Add one compact rule at the bottom: `同一文件只能有一个 Owner · 重叠范围不得并发`.
Use one Sol core in the routed lane and three separated Luna nodes. No line may
imply Luna-to-Luna delegation.

- [ ] **Step 4: Create the English control-plane explainer**

Reuse the Chinese geometry with independently fitted strings:

```text
DIRECT      Current Codex completes the task        Zero delegation
SOL-ONLY    Plan / decide / review                   No Luna
SOL → LUNA  Bounded task → unique owner → evidence  PASS / FIX / BLOCKED
One file, one owner · overlapping scopes never run concurrently
```

- [ ] **Step 5: Run the asset contract and prove GREEN**

Run:

```bash
python3 -m unittest tests.test_readme_control_orbit_assets -v
git diff --check
```

Expected: all asset tests PASS and `git diff --check` produces no output.

- [ ] **Step 6: Commit the SVG assets**

```bash
git add docs/assets/readme tests/test_readme_control_orbit_assets.py
git commit -m "docs: add bilingual control orbit visuals"
```

### Task 3: Render and Review the Preview

**Files:**
- Read: `docs/assets/readme/*.svg`
- Create outside repository: `/Users/kin3/.codex/visualizations/2026/08/01/019fbd2b-f26c-7c13-929a-f396a14af022/readme-control-orbit-preview.html`
- Create outside repository: rendered PNG derivatives under a temporary directory.

- [ ] **Step 1: Render all SVGs to PNG**

Run:

```bash
preview_dir=$(mktemp -d /tmp/sol-luna-control-orbit.XXXXXX)
for svg in docs/assets/readme/*.svg; do
  sips -s format png "$svg" --out "$preview_dir/$(basename "${svg%.svg}").png"
done
```

Expected: four PNG files with successful `sips` conversion.

- [ ] **Step 2: Create a README-width visual preview**

Create a local HTML page with:

```css
.github-column { width: min(900px, calc(100vw - 32px)); margin: 32px auto; }
img { display: block; width: 100%; height: auto; }
@media (max-width: 420px) { .github-column { margin: 16px auto; } }
```

Show Chinese and English tabs side by side in the navigation, but only one
localized README surface at a time. The visible surface must include the hero,
one paragraph qualifying 59% and Direct 0%, the control-plane explainer, and the
60-second quick-start command block.

- [ ] **Step 3: Inspect wide and narrow layouts**

Inspect at 900px and 360px widths. Passing conditions:

- no clipped text;
- project name and 59% remain the first visual hierarchy;
- Sol is singular and dominant;
- all Luna task paths are disjoint;
- evidence visibly returns to Sol;
- essential English and Chinese labels remain readable;
- no current README file has changed.

- [ ] **Step 4: Present the local preview for user approval**

Open the local preview in the Codex in-app browser. Report the asset files and
leave `README.md`, `README.en.md`, installers, and validators untouched. Stop for
visual approval before Task 4.

### Task 4: Integrate the Approved Reading Order

**Files:**
- Modify: `README.md`
- Modify: `README.en.md`
- Modify: `tests/test_readme.py`
- Test: `tests/test_readme.py`

- [ ] **Step 1: Update the README contract and prove RED**

Change `SVG_FILES` and `EXPECTED_IMAGE_TARGETS` to the four localized assets.
Assert Chinese embeds use `hero-zh.svg` then `control-plane-zh.svg`, while
English embeds use `hero-en.svg` then `control-plane-en.svg`. Replace the old
shared four-image sequence assertion with per-language two-image sequence
assertions. Update the section map and expected order to:

```python
EXPECTED_SECTION_KEYS = (
    "quickstart",
    "routing",
    "reliability",
    "cost_details",
    "platform",
    "benchmark",
    "repository",
    "limitations",
    "prior_art",
)
```

Run:

```bash
python3 -m unittest tests.test_readme -v
```

Expected: FAIL because the READMEs still embed the old assets and use the old
section order.

- [ ] **Step 2: Rewrite the Chinese README opening and sequence**

Keep the language switch, embed `hero-zh.svg`, then provide one short paragraph
that includes all of these facts in searchable Markdown:

```text
Sol is the single controller.
Luna Max executes bounded tasks and returns evidence.
59% is an estimate for suitable routine routed work, not a guarantee.
Direct tasks use zero delegation and claim 0% routing savings.
Complex rework-prone tasks may reach about 65% only under the stated assumptions.
```

Embed `control-plane-zh.svg` immediately after that paragraph. Follow it with
the 60-second quick start, then routing, reliability, cost details, platforms,
benchmark, repository validation, limitations, prior art/license, and the exact
final LINUX DO acknowledgement.

- [ ] **Step 3: Rewrite the English README to the same structure**

Use `hero-en.svg` and `control-plane-en.svg`. Preserve every cost qualifier,
platform boundary, command, license statement, and the localized final LINUX DO
acknowledgement. Do not translate identifiers, paths, model names, or commands.

- [ ] **Step 4: Prove the bilingual README contract GREEN**

Run:

```bash
python3 -m unittest tests.test_readme -v
```

Expected: all README contract tests PASS.

- [ ] **Step 5: Commit the approved README integration**

```bash
git add README.md README.en.md tests/test_readme.py
git commit -m "docs: integrate control orbit README story"
```

### Task 5: Update Lifecycle Manifests and Remove Superseded Assets

**Files:**
- Modify: `scripts/validate.sh`
- Modify: `scripts/validate.ps1`
- Modify: `scripts/install.sh`
- Modify: `scripts/install.ps1`
- Modify: `tests/test_contract.py`
- Modify: `tests/test_installers.py`
- Delete: `docs/assets/sol-luna-hero.svg`
- Delete: `docs/assets/sol-luna-architecture.svg`
- Delete: `docs/assets/sol-luna-routing.svg`
- Delete: `docs/assets/sol-luna-review.svg`

- [ ] **Step 1: Update lifecycle tests and prove RED**

Replace the old asset paths in required-file and installed-file expectations
with:

```text
docs/assets/readme/hero-zh.svg
docs/assets/readme/hero-en.svg
docs/assets/readme/control-plane-zh.svg
docs/assets/readme/control-plane-en.svg
```

Run:

```bash
python3 -m unittest tests.test_contract tests.test_installers -v
```

Expected: FAIL until the shell and PowerShell manifests use the new paths.

- [ ] **Step 2: Update the POSIX manifests**

Replace the old README asset entries in `scripts/validate.sh` and
`scripts/install.sh` with all four new asset paths. Preserve literal-path safety,
backup behavior, and all unrelated installed targets.

- [ ] **Step 3: Update the PowerShell manifests**

Replace the old README asset entries in `scripts/validate.ps1` and
`scripts/install.ps1` with all four new asset paths. Preserve Windows PowerShell
5.1 syntax and all unrelated installed targets.

- [ ] **Step 4: Remove only unreferenced superseded assets**

Run:

```bash
rg -n 'docs/assets/sol-luna-(hero|architecture|routing|review)\.svg' .
```

Expected before deletion: no references outside historical design/plan
documents. Delete the four old SVG files with an exact patch; do not remove the
`docs/assets` directory.

- [ ] **Step 5: Run focused lifecycle verification**

Run:

```bash
python3 -m unittest tests.test_contract tests.test_installers -v
bash -n scripts/validate.sh scripts/install.sh scripts/uninstall.sh
```

Expected: all focused tests PASS and shell syntax checks return exit code 0.

- [ ] **Step 6: Commit lifecycle alignment**

```bash
git add scripts tests docs/assets
git commit -m "chore: align installers with README assets"
```

### Task 6: Final Audit and Delivery Gate

**Files:**
- Verify: all changed repository files.

- [ ] **Step 1: Run the external README audit**

Run from the temporary `beautify-github-readme` checkout:

```bash
python3 /tmp/beautify-readme.30addO/repo/skills/beautify-github-readme/scripts/audit_readme.py README.md
python3 /tmp/beautify-readme.30addO/repo/skills/beautify-github-readme/scripts/audit_readme.py README.en.md
```

Expected: both audits report `OK`.

- [ ] **Step 2: Run the repository verification suite**

Run:

```bash
bash scripts/validate.sh
bash scripts/test.sh
git diff --check
git status --short
```

Expected: validator and tests return exit code 0, whitespace check is silent,
and status contains only the expected README redesign branch state.

- [ ] **Step 3: Verify no sensitive or external raster content**

Run:

```bash
rg -n '(BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|api[_-]?key|token\s*=|data:image|<foreignObject|https?://)' docs/assets/readme
```

Expected: no secret patterns, raster data, `foreignObject`, or external resource
references. Repository URLs inside README Markdown are outside this SVG-only
check.

- [ ] **Step 4: Inspect the final GitHub-width preview**

Re-render the committed assets and inspect 900px and 360px layouts in both
languages. Verify the final README still ends with the required LINUX DO thanks.

- [ ] **Step 5: Report without publishing**

Report the branch, commits, changed files, preview location, and exact test
results. Do not push, merge to `main`, tag, or add optional attribution until the
user explicitly authorizes that action.
