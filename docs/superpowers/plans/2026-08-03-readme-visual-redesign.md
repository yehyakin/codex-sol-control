# Sol Luna README Visual Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dense bilingual documentation surface with a polished Chinese-first open-source homepage and four original Sol-architect/Luna-workshop illustrations while preserving every evidence and platform contract.

**Architecture:** Freeze the new documentation contract in RED tests first. Then produce repository-owned pure-vector artwork and rewrite both README files under separate, non-overlapping ownership. Integrate only after the targeted contracts pass, render the SVGs for visual review, run the full validation suite, and submit the final files and diff to Sol for evidence-based review.

**Tech Stack:** GitHub-flavored Markdown, SVG 1.1-compatible XML, Python 3.11+ `unittest`, POSIX validation scripts, Git

---

## File map and ownership

| File | Responsibility | Owner for this run |
| --- | --- | --- |
| `tests/test_readme.py` | Bilingual structure, image, accessibility, originality, and evidence contracts | README contract worker |
| `docs/assets/sol-luna-hero.svg` | Wide first-screen visual | Artwork worker |
| `docs/assets/sol-luna-architecture.svg` | Sol controller and Luna workshop cutaway | Artwork worker |
| `docs/assets/sol-luna-routing.svg` | Direct, Sol-only, and Sol-to-Luna routing | Artwork worker |
| `docs/assets/sol-luna-review.svg` | Files, diff, test, and Sol verdict evidence loop | Artwork worker |
| `README.md` | Default Chinese project homepage | Bilingual README worker |
| `README.en.md` | Fact-aligned English peer | Bilingual README worker |
| `docs/superpowers/specs/2026-08-03-readme-visual-redesign-design.md` | Approved design; read-only during implementation | Main Codex |
| `docs/superpowers/plans/2026-08-03-readme-visual-redesign.md` | This execution plan; read-only after commit | Main Codex |

No worker may modify runtime Skill files, agent TOML files, lifecycle scripts,
benchmark fixtures/reports, global installations, or files outside the repository.

### Task 1: Freeze the new README and artwork contract

**Files:**
- Modify: `tests/test_readme.py`
- Test: `tests/test_readme.py`

- [ ] **Step 1: Expand the owned SVG list and stable section map**

Replace `SVG_FILES` with:

```python
SVG_FILES = (
    ROOT / "docs" / "assets" / "sol-luna-hero.svg",
    ROOT / "docs" / "assets" / "sol-luna-architecture.svg",
    ROOT / "docs" / "assets" / "sol-luna-routing.svg",
    ROOT / "docs" / "assets" / "sol-luna-review.svg",
)

EXPECTED_IMAGE_TARGETS = tuple(
    path.relative_to(ROOT).as_posix() for path in SVG_FILES
)

SECTION_HEADING_PATTERNS = (
    ("quickstart", re.compile(r"(?i)60[- ]second|quickstart|60 秒|快速开始")),
    ("architecture", re.compile(r"(?i)one controller|execution workshop|单一主控|执行工坊")),
    ("routing", re.compile(r"(?i)choose the route|routing|选择路径|路由")),
    ("workflow", re.compile(r"(?i)workflow|工作流")),
    ("reliability", re.compile(r"(?i)reliab|boundary|可靠|边界")),
    ("benchmark", re.compile(r"(?i)real[- ]project routing samples|真实项目路由样本")),
    ("cost_details", re.compile(r"(?i)cost model|evidence boundary|成本模型|证据边界")),
    ("platform", re.compile(r"(?i)platform|lifecycle|平台|生命周期")),
    ("repository", re.compile(r"(?i)repository|development|仓库|开发验证")),
    ("limitations", re.compile(r"(?i)limitations?|限制")),
    ("prior_art", re.compile(r"(?i)prior art|license|acknowledg|先例|许可证|致谢")),
)
```

- [ ] **Step 2: Replace the first-screen test with the approved claims**

Use this test so the headline and its guardrails stay together:

```python
def test_chinese_readme_is_cost_first_and_conditioned(self) -> None:
    text = CHINESE_README.read_text(encoding="utf-8")
    first_screen = "\n".join(text.splitlines()[:48])
    self.assertIn("普通任务约节省 59%", first_screen)
    self.assertRegex(first_screen, r"复杂且容易返工任务.{0,40}65%")
    self.assertRegex(first_screen, r"估算|不是.{0,20}保证")
    self.assertRegex(first_screen, r"(?:Direct|直接)[^\n]{0,100}0%")
    self.assertLess(text.index("59%"), text.index("## 60 秒开始"))
```

- [ ] **Step 3: Require all four images in matching order with localized alt text**

Replace the current two-image test with:

```python
def image_sequence(self, text: str) -> list[tuple[str, str]]:
    images: list[tuple[str, str]] = []
    for match in MARKDOWN_IMAGE_RE.finditer(text):
        target = match.group("bracketed") or match.group("plain")
        parsed = urlsplit(target)
        self.assertFalse(parsed.scheme or parsed.netloc, target)
        images.append((match.group("alt").strip(), target.split("#", 1)[0]))
    return images

def test_readmes_use_the_four_local_images_in_the_same_order(self) -> None:
    documents = self.readme_documents()
    sequences = {path: self.image_sequence(text) for path, text in documents.items()}
    for path, sequence in sequences.items():
        self.assertEqual(list(EXPECTED_IMAGE_TARGETS), [target for _, target in sequence], path.name)
        self.assertTrue(all(alt for alt, _ in sequence), path.name)
    self.assertNotEqual(
        [alt for alt, _ in sequences[CHINESE_README]],
        [alt for alt, _ in sequences[ENGLISH_README]],
        "image alt text must be localized",
    )
```

- [ ] **Step 4: Strengthen the SVG purity and originality checks**

After the existing title, description, and external-URL checks, add:

```python
self.assertNotRegex(source, r"(?is)<image\b|data:image|<foreignObject\b")
self.assertNotRegex(source, r"(?is)<linearGradient\b|<radialGradient\b")
self.assertNotRegex(source, r"(?i)oil-visual|border collie|边牧|圆框眼镜")
self.assertIn("#F4E8D3", source, path.name)
self.assertIn("#17130F", source, path.name)
self.assertIn("#D95F32", source, path.name)
self.assertIn("#416C8A", source, path.name)
```

- [ ] **Step 5: Freeze the final acknowledgement exactly**

Update the Chinese assertion to match the user's approved punctuation:

```python
self.assertTrue(
    chinese.rstrip().endswith(
        "**致谢 / Thanks**\n\n"
        "感谢 [LINUX DO 论坛](https://linux.do/) 社区的关注、反馈与支持"
    )
)
```

Keep the English peer assertion and additionally require its acknowledgement to be the
last block.

- [ ] **Step 6: Run RED and record the expected failure boundary**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest tests.test_readme -v
```

Expected: non-zero exit. Failures must be limited to the two missing SVGs, the old image
sequence, the old section hierarchy, the old first-screen wording, or the old Chinese
acknowledgement punctuation. Existing canonical URL, pricing, platform, and link tests
must not newly fail.

- [ ] **Step 7: Commit the RED contract**

```bash
git add tests/test_readme.py
git commit -m "test: define polished README contract"
```

### Task 2: Create the original four-illustration system

**Files:**
- Modify: `docs/assets/sol-luna-hero.svg`
- Modify: `docs/assets/sol-luna-architecture.svg`
- Create: `docs/assets/sol-luna-routing.svg`
- Create: `docs/assets/sol-luna-review.svg`
- Test: `tests/test_readme.py`

- [ ] **Step 1: Establish one reusable SVG visual vocabulary**

Each SVG must start with the same accessible and rendering-safe structure, adjusted only
for the intended `viewBox` and localized description:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1440 480" role="img" aria-labelledby="title desc">
  <title id="title">Sol Luna orchestration workshop</title>
  <desc id="desc">Sol plans and reviews while bounded Luna work cells execute and return evidence.</desc>
  <defs>
    <pattern id="halftone" width="12" height="12" patternUnits="userSpaceOnUse">
      <circle cx="3" cy="3" r="1.6" fill="#17130F" opacity="0.28"/>
    </pattern>
  </defs>
  <rect width="100%" height="100%" fill="#F4E8D3"/>
  <!-- Use #17130F ink, #D95F32 Sol accents, and #416C8A Luna accents. -->
</svg>
```

Do not use `font-family` declarations that depend on a remote font. Text is limited to
short labels and must remain readable with the generic SVG default.

- [ ] **Step 2: Redraw the hero at 1440 by 480**

Build a central orange blueprint desk marked `SOL`, three separated blue Luna work cells,
bounded work-order cards, and a black evidence-return rail. Keep the main silhouette away
from a left-copy/right-character layout. Use decorative registration marks and halftone
shadows only where they improve depth.

- [ ] **Step 3: Redraw the architecture cutaway at 1440 by 810**

Build an upper planning room with one Sol console, a lower workshop with three separated
Luna bays, one shared but non-writable return lift, and visible file-ownership labels
`A`, `B`, and `C`. The diagram must make parallelism and disjoint write scopes visible
without a paragraph embedded in the image.

- [ ] **Step 4: Create the routing diagram at 1200 by 720**

Show three routes from one incoming task card:

```text
DIRECT -> DONE
SOL ONLY -> PLAN / REVIEW
SOL -> LUNA -> EVIDENCE -> SOL
```

The Direct route is shortest. The Sol-only route stops before any Luna bay. The delegated
route is visually longer and includes bounded work cells.

- [ ] **Step 5: Create the review diagram at 1200 by 720**

Show evidence trays marked `FILES`, `DIFF`, and `TEST` entering Sol's inspection lightbox.
Show three verdict stamps, `PASS`, `FIX`, and `BLOCKED`, with only one stamp applied to an
outgoing delivery card. Do not show Luna approving the final card.

- [ ] **Step 6: Run the SVG contract and forbidden-pattern scan**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest tests.test_readme.ReadmeContractTests.test_svg_assets_are_well_formed_local_and_accessible -v
```

Expected: PASS.

Run:

```bash
rg -n '<image|data:image|(?:href|src)="https?://|@import|linearGradient|radialGradient|oil-visual|边牧|圆框眼镜' docs/assets/sol-luna-*.svg
```

Expected: no output and exit status 1 because no forbidden pattern is present.

- [ ] **Step 7: Render and inspect the four illustrations**

Render each SVG at its native canvas and inspect at simulated 1440, 768, and 375 pixel
README widths. Passing conditions:

- no clipping or unreadable essential label;
- visual order still reads Sol to Luna to evidence to Sol;
- black ink retains sufficient contrast on warm paper;
- Sol orange and Luna blue remain distinguishable without becoming the only carrier of
  meaning;
- the result is visibly original when compared side-by-side with the reference README.

- [ ] **Step 8: Commit artwork**

```bash
git add docs/assets/sol-luna-hero.svg docs/assets/sol-luna-architecture.svg docs/assets/sol-luna-routing.svg docs/assets/sol-luna-review.svg
git commit -m "docs: add original Sol Luna workshop artwork"
```

### Task 3: Rewrite the Chinese and English README as one product surface

**Files:**
- Modify: `README.md`
- Modify: `README.en.md`
- Test: `tests/test_readme.py`
- Test: `tests/test_benchmark.py`

- [ ] **Step 1: Replace the Chinese first screen**

Use this content order and wording at the top of `README.md`:

```markdown
[简体中文](README.md) · [English](README.en.md)

![Sol 建筑师向 Luna 执行工坊分配有边界任务，证据返回 Sol 审核](docs/assets/sol-luna-hero.svg)

# Sol Luna

**Sol 单一主控。Luna Max 有界执行。真实文件与证据通过后才交付。**

`codex-sol-luna` 是一个小型、通用的 Codex 编排 Skill。简单任务由当前 Codex
直接完成；复杂任务由 Sol 理解、规划、分配和审核，Luna Max 负责执行清晰的子任务。

| 普通任务 | 复杂且容易返工任务 |
| --- | --- |
| **约节省 59%** | **在估算条件下约节省 65%** |

两项均为估算，不是实测保证。59% 指适合有边界委派的典型任务；简单 Direct
任务零委派，路由节省为 **0%**。65% 是在典型估算后再避免部分无效返工的条件化结果。

## 60 秒开始
```

Immediately follow with the canonical repository link, `$sol-luna` invocation, and the
short macOS/Linux validation and installation command. Link Windows users to the later
platform section rather than placing the full PowerShell matrix above the architecture.

- [ ] **Step 2: Create the fact-aligned English first screen**

Use the same image path, table shape, numbers, disclaimer order, and quickstart command.
The headline wording is:

```markdown
**One Sol controller. Bounded Luna Max execution. Delivery only after real files and evidence pass review.**
```

The cost labels are `Typical delegable work — about 59%` and `Complex, rework-prone work — about 65% under the stated estimate`.

- [ ] **Step 3: Write the shared core narrative and place the remaining images**

Use these matching second-level headings:

```text
中文                                      English
## 单一主控，一座执行工坊                 ## One controller, one execution workshop
## 选择路径                               ## Choose the route
## 工作流                                 ## Workflow
## 可靠性来自边界                         ## Reliability comes from boundaries
## 真实项目路由样本                       ## Real-project routing samples
## 成本模型与证据边界                     ## Cost model and evidence boundaries
## 平台与生命周期                         ## Platforms and lifecycle
## 仓库与开发验证                         ## Repository and development
## 限制                                   ## Limitations
## 先例与许可证                           ## Prior art and license
```

Place `sol-luna-architecture.svg`, `sol-luna-routing.svg`, and `sol-luna-review.svg` in
that order under the architecture, routing, and workflow/reliability narrative.

- [ ] **Step 4: Preserve technical facts while collapsing dense details**

Use named `<details>` blocks for:

- exact custom-agent identities and result/correction/resume packet detail;
- complete macOS/Linux and PowerShell lifecycle commands;
- API and ChatGPT rate tables plus the formula and scenarios;
- repository layout, validation commands, and evidence limitations.

Keep all strings asserted by `tests/test_readme.py` and `tests/test_benchmark.py`, including
the exact pricing rows and this formula:

```text
savings = delegated_share * (1 - luna_duplication / 25) - sol_overhead
```

Keep the conditioned estimate on a single searchable line in both files:

```text
41% * 85% = 34.85%, therefore about 65% saved (sample-validated projection)
```

Translate the surrounding Chinese prose, but do not change the tokens, percentages, or
evidence labels.

- [ ] **Step 5: End both files with the approved acknowledgement**

The final Chinese block must be exactly:

```markdown
**致谢 / Thanks**

感谢 [LINUX DO 论坛](https://linux.do/) 社区的关注、反馈与支持
```

The English final block must be:

```markdown
**致谢 / Thanks**

Thank you to the [LINUX DO forum](https://linux.do/) community for its attention,
feedback, and support.
```

- [ ] **Step 6: Run the targeted documentation contracts**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest tests.test_readme tests.test_benchmark -v
```

Expected: all tests PASS.

- [ ] **Step 7: Commit the bilingual README rewrite**

```bash
git add README.md README.en.md
git commit -m "docs: redesign bilingual project homepage"
```

### Task 4: Integrate, verify, and review the final candidate

**Files:**
- Inspect: `README.md`
- Inspect: `README.en.md`
- Inspect: `docs/assets/sol-luna-*.svg`
- Inspect: `tests/test_readme.py`
- Inspect: complete diff from the design commit
- Modify: only the original owner may make one focused same-scope correction if Sol returns `FIX`

- [ ] **Step 1: Check actual changed paths and whitespace**

Run:

```bash
git status --short
git diff --check HEAD~3..HEAD
git diff --name-only HEAD~3..HEAD
```

Expected changed implementation paths are exactly the two README files, four SVG files,
`tests/test_readme.py`, the approved design spec, and this plan. Stop if runtime, agent,
installer, benchmark fixture/report, global, or unrelated paths appear.

- [ ] **Step 2: Run the focused suite**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest tests.test_readme tests.test_benchmark -v
```

Expected: PASS with no failure or error.

- [ ] **Step 3: Run the complete repository verification**

```bash
bash scripts/test.sh
bash scripts/validate.sh
git diff --check
```

Expected: every command exits 0 and validation prints `Validation: PASS`.

- [ ] **Step 4: Inspect links, source privacy, and artwork safety**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest tests.test_benchmark.RealProjectBenchmarkTests.test_public_artifacts_contain_no_private_paths_or_source_identity_fields -v
rg -n '<image|data:image|(?:href|src)="https?://|@import|linearGradient|radialGradient|oil-visual|边牧|圆框眼镜' docs/assets/sol-luna-*.svg
```

Expected: the privacy test passes. The artwork scan produces no output and exits 1 because
none of the forbidden patterns is present.

- [ ] **Step 5: Ask Sol to review the real candidate**

Provide Sol with:

- the original user request and approved design;
- the final commit identity and full diff;
- actual changed-file list;
- targeted and complete test output;
- rendered artwork paths and visual inspection notes;
- known platform evidence boundaries;
- any uncommitted user changes.

Sol must check cost wording, bilingual parity, originality, one-controller architecture,
scope, evidence quality, and the exact final acknowledgement. Verdict must be `PASS`,
`FIX`, or `BLOCKED`.

- [ ] **Step 6: Apply at most one focused correction if required**

A `FIX` packet must retain the original file owner and original scope and include the
observed failure, evidence, exact correction, and exact regression command. A second
failure becomes `BLOCKED`; do not broaden the redesign.

- [ ] **Step 7: Push only after final PASS**

```bash
git status --short --branch
git log -4 --oneline
git push origin main
```

Expected: worktree clean, branch `main`, push succeeds, and remote `main` resolves to the
reviewed final commit.

## Plan self-review

- Spec coverage: all first-screen, routing, artwork, bilingual, cost, platform,
  acknowledgement, validation, and scope requirements map to a task above.
- Placeholder scan: passed; no deferred implementation or unspecified test step remains.
- Consistency: all four asset paths, cost values, heading order, commands, and result
  boundaries match the approved design.
- Ownership: the tests, artwork, and bilingual README scopes are disjoint; README files
  have one shared owner to preserve parity.
