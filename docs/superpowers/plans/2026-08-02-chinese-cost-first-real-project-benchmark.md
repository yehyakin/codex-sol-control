# Chinese Cost-First README and Real-Project Benchmark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the canonical GitHub README Chinese and cost-first, preserve a complete English peer, and publish a privacy-safe real-project routing benchmark without modifying any business repository.

**Architecture:** Rename the two README peers so `README.md` is Chinese and `README.en.md` is English, then enforce language, section order, and cost-claim boundaries through repository contracts. Build the benchmark from existing read-only task evidence first, use only the minimum controlled read-only gap probes, and commit only anonymous aggregate data labeled `measured`, `estimated`, or `unavailable`.

**Tech Stack:** Markdown, Python 3.11+ `unittest` and `json`, Bash, Windows PowerShell 5.1/7, GitHub Actions.

---

## File map

| File | Responsibility |
| --- | --- |
| `README.md` | Canonical Simplified Chinese user guide and cost-first landing page |
| `README.en.md` | Complete English peer with the same facts and section order |
| `tests/test_readme.py` | README naming, language switching, order, links, cost, and parity contracts |
| `tests/test_contract.py` | Repository-required file and Chinese-default contracts |
| `tests/test_benchmark.py` | Benchmark schema, evidence labels, privacy, and claim-boundary contracts |
| `tests/fixtures/real-project-benchmark.json` | Machine-checkable anonymous aggregate evidence |
| `tests/real-project-benchmark.md` | Human-readable method, aggregate result, limitations, and run date |
| `scripts/validate.sh` | POSIX required-source validation for the new README names |
| `scripts/validate.ps1` | PowerShell required-source validation for the new README names |
| `scripts/install.ps1` | Windows install preflight source list for the new README names |
| `tests/test_installers.py` | Installer contract expectation for the renamed English README |

Historical v0.3.0 design records remain historical. Do not rewrite them merely
to replace old filenames. Current user documentation, validators, installer
preflights, and tests must use the new names.

### Task 1: Lock the Chinese canonical README contract

**Files:**
- Modify: `tests/test_readme.py`
- Modify: `tests/test_contract.py`

- [ ] **Step 1: Write the failing README naming and first-screen tests**

Replace the README constants in `tests/test_readme.py` with:

```python
CHINESE_README = ROOT / "README.md"
ENGLISH_README = ROOT / "README.en.md"
README_FILES = (CHINESE_README, ENGLISH_README)
```

Replace the language-switch test with:

```python
def test_both_complete_readmes_exist_and_start_with_language_switches(self) -> None:
    documents = self.readme_documents()
    chinese_head = "\n".join(documents[CHINESE_README].splitlines()[:24])
    english_head = "\n".join(documents[ENGLISH_README].splitlines()[:24])

    self.assertRegex(chinese_head, r"\[简体中文\]\(README\.md\)")
    self.assertRegex(chinese_head, r"\[English\]\(README\.en\.md\)")
    self.assertRegex(english_head, r"\[简体中文\]\(README\.md\)")
    self.assertRegex(english_head, r"\[English\]\(README\.en\.md\)")
```

Add this test to `ReadmeContractTests`:

```python
def test_chinese_readme_is_cost_first(self) -> None:
    text = CHINESE_README.read_text(encoding="utf-8")
    first_screen = "\n".join(text.splitlines()[:48])
    self.assertIn("成本约节省 59%", first_screen)
    self.assertRegex(first_screen, r"保守.{0,20}38%")
    self.assertRegex(first_screen, r"执行密集.{0,20}74%")
    self.assertRegex(first_screen, r"估算|不是.{0,20}保证")
    self.assertLess(text.index("成本约节省 59%"), text.index("## 架构"))
```

Replace `SECTION_HEADING_PATTERNS` so the first-screen cost claim and the later
detailed pricing section are independently ordered:

```python
SECTION_HEADING_PATTERNS = (
    ("headline_cost", re.compile(r"(?i)estimated\s+cost\s+saving|成本约节省")),
    ("architecture", re.compile(r"(?i)architecture|架构")),
    (
        "use",
        re.compile(
            r"(?i)when\s+to\s+use|when\s+not\s+to\s+use|use\s*/?\s*not|use\s+cases|"
            r"使用场景|何时使用|不使用"
        ),
    ),
    ("platform", re.compile(r"(?i)platform|quickstart|平台|快速开始|快速入门")),
    (
        "reliability",
        re.compile(r"(?i)reliab|identity|ownership|evidence|correction|可靠|身份|所有权|证据|修正"),
    ),
    ("benchmark", re.compile(r"(?i)real[- ]project\s+benchmark|真实项目基准")),
    ("cost_details", re.compile(r"(?i)cost\s+model|pricing\s+snapshot|成本模型|价格快照")),
    (
        "repository",
        re.compile(
            r"(?i)repository\s+(?:layout|structure)|testing|limitations?|prior\s+art|license|"
            r"仓库(?:布局|结构)|测试|限制|先例|许可证|许可"
        ),
    ),
)
```

In `tests/test_contract.py`, change the current required README entry and
repository loop to `README.en.md`, then replace the README part of
`test_runtime_defaults_to_chinese_unless_the_user_overrides_it` with:

```python
chinese_readme = read_if_present(ROOT / "README.md")
english_readme = read_if_present(ROOT / "README.en.md")
self.assertIn("运行时默认使用简体中文", chinese_readme)
self.assertIn("Runtime output defaults to Simplified Chinese", english_readme)
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
/opt/homebrew/bin/python3.13 -m unittest \
  tests.test_readme.ReadmeContractTests.test_both_complete_readmes_exist_and_start_with_language_switches \
  tests.test_readme.ReadmeContractTests.test_chinese_readme_is_cost_first \
  tests.test_contract.RepositoryContractTests.test_required_v030_files_exist -v
```

Expected: non-zero exit because `README.en.md` is absent and the canonical
`README.md` does not contain the Chinese cost-first headline.

### Task 2: Rename and restructure the bilingual README pair

**Files:**
- Rename: `README.md` to `README.en.md`
- Rename: `README.zh-CN.md` to `README.md`
- Modify: `scripts/validate.sh`
- Modify: `scripts/validate.ps1`
- Modify: `scripts/install.ps1`
- Modify: `tests/test_installers.py`
- Test: `tests/test_readme.py`
- Test: `tests/test_contract.py`

- [ ] **Step 1: Preserve Git history while changing the canonical language**

Run:

```bash
git mv README.md README.en.md
git mv README.zh-CN.md README.md
```

- [ ] **Step 2: Install the exact Chinese first-screen block**

Replace the current top language switch and introduction in `README.md` with
this block, retaining the existing repository-owned hero and architecture SVGs
after it:

```markdown
[简体中文](README.md) · [English](README.en.md)

# Sol Luna

`codex-sol-luna` 是一个刻意保持小型、清晰的 Codex 编排 Skill：Sol 是唯一
主控，负责理解、规划、拆分、分配和审核；Luna Max 只执行有边界的任务、完成
自检并返回证据。

## 成本约节省 59%

在当前典型模型中，把约 70% 的执行工作交给 Luna Max，即使 Luna 为完成这些
工作使用约 115% 的相对 token，并增加约 8% 的 Sol 规划与审核开销，整个工作流
的估算成本仍可下降约 **59%**。

**保守场景约节省 38% · 执行密集场景约节省 74%**

这是基于 2026-08-02 价格快照和公开公式得到的估算，不是每个任务的保证。
简单 Direct 任务的路由节省为 0%；重复上下文、错误拆分、重试或过重的 Sol
审核都可能降低甚至抵消节省。完整价格、公式和证据边界见后文。
```

Keep the existing `# Sol Luna` hero image immediately after this cost block,
then use the confirmed section order:

```text
架构
何时使用，以及何时保持直接执行
平台支持与快速开始
为什么可靠：身份、所有权、证据与修正
真实项目基准
成本模型与价格快照
仓库布局、测试、限制、先例与许可证
```

Merge the current runtime and ownership sections under the reliability section
without dropping any exact model, sandbox, packet, result, or correction fact.

- [ ] **Step 3: Mirror the same order and claim boundary in English**

Set the top of `README.en.md` to:

```markdown
[简体中文](README.md) · [English](README.en.md)

# Sol Luna

`codex-sol-luna` is a deliberately small Codex orchestration Skill: Sol is the
single controller that understands, plans, splits, assigns, and reviews; Luna
Max executes bounded tasks, verifies the work, and returns evidence.

## Estimated cost saving: about 59%

Under the current typical model, Luna Max performs about 70% of the execution
work at 115% of the delegated token baseline while added Sol planning and review
costs 8%. The resulting whole-workflow estimate is about **59% lower**.

**Conservative estimate: about 38% · Execution-heavy estimate: about 74%**

This is a modeled estimate based on the 2026-08-02 pricing snapshot and public
formula, not a guarantee for every task. Direct tasks claim 0% routing savings;
repeated context, poor decomposition, retries, or heavy Sol review can reduce or
erase the benefit. Full pricing, formula, and evidence boundaries appear below.
```

Use English headings that match the Chinese order exactly.

- [ ] **Step 4: Update current validators and installer preflights**

Replace current, non-historical occurrences of `README.zh-CN.md` with
`README.en.md` in:

```text
scripts/validate.sh
scripts/validate.ps1
scripts/install.ps1
tests/test_installers.py
tests/test_readme.py
tests/test_contract.py
```

Do not alter `.agents/skills/sol-luna`, either agent TOML, or historical design
documents in this task.

- [ ] **Step 5: Run README and repository contracts**

Run:

```bash
/opt/homebrew/bin/python3.13 -m unittest tests.test_readme tests.test_contract tests.test_installers -v
```

Expected: all selected tests pass, with no broken relative README link.

- [ ] **Step 6: Commit the canonical-language change**

```bash
git add README.md README.en.md scripts/validate.sh scripts/validate.ps1 \
  scripts/install.ps1 tests/test_readme.py tests/test_contract.py \
  tests/test_installers.py
git commit -m "docs: make Chinese the canonical cost-first README"
```

### Task 3: Define the benchmark evidence and privacy contract

**Files:**
- Create: `tests/test_benchmark.py`
- Create: `tests/fixtures/real-project-benchmark.json`

- [ ] **Step 1: Write the failing benchmark contract**

Create `tests/test_benchmark.py` with:

```python
#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests" / "fixtures" / "real-project-benchmark.json"
REPORT = ROOT / "tests" / "real-project-benchmark.md"
README_FILES = (ROOT / "README.md", ROOT / "README.en.md")
ALLOWED_EVIDENCE = {"measured", "estimated", "unavailable"}
EXPECTED_CATEGORIES = {"codebase", "documentation", "infrastructure"}
PRIVATE_PATH_RE = re.compile(r"(?:/Users/|[A-Za-z]:[\\/]Users[\\/])")


class RealProjectBenchmarkTests(unittest.TestCase):
    def load_fixture(self) -> dict:
        self.assertTrue(FIXTURE.is_file(), FIXTURE)
        return json.loads(FIXTURE.read_text(encoding="utf-8"))

    def test_fixture_has_three_anonymous_categories(self) -> None:
        data = self.load_fixture()
        categories = data["categories"]
        self.assertEqual(EXPECTED_CATEGORIES, {item["id"] for item in categories})
        self.assertTrue(all(item["sample_count"] >= 1 for item in categories))

    def test_every_metric_declares_a_valid_evidence_class(self) -> None:
        data = self.load_fixture()
        metrics = list(data["cost"].values())
        for category in data["categories"]:
            metrics.extend(category["metrics"].values())
        for metric in metrics:
            self.assertIn(metric["evidence"], ALLOWED_EVIDENCE)
            if metric["evidence"] == "unavailable":
                self.assertIsNone(metric["value"])

    def test_public_artifacts_contain_no_private_paths_or_source_identity_fields(self) -> None:
        texts = [FIXTURE.read_text(encoding="utf-8")]
        if REPORT.is_file():
            texts.append(REPORT.read_text(encoding="utf-8"))
        combined = "\n".join(texts)
        self.assertNotRegex(combined, PRIVATE_PATH_RE)
        data = self.load_fixture()
        forbidden_keys = {"project_name", "project_path", "repository_url", "thread_id", "prompt"}
        serialized_keys = set()

        def collect_keys(value: object) -> None:
            if isinstance(value, dict):
                serialized_keys.update(value)
                for child in value.values():
                    collect_keys(child)
            elif isinstance(value, list):
                for child in value:
                    collect_keys(child)

        collect_keys(data)
        self.assertTrue(forbidden_keys.isdisjoint(serialized_keys))

    def test_measured_cost_requires_exact_usage_evidence(self) -> None:
        cost = self.load_fixture()["cost"]
        measured = cost["measured_workflow_saving_percent"]
        exact_usage = cost["exact_per_model_usage_available"]
        if measured["evidence"] == "measured":
            self.assertIs(exact_usage["value"], True)
            self.assertEqual("measured", exact_usage["evidence"])
        else:
            self.assertIsNone(measured["value"])

    def test_report_and_readmes_publish_the_same_evidence_boundary(self) -> None:
        self.assertTrue(REPORT.is_file(), REPORT)
        report = REPORT.read_text(encoding="utf-8")
        for signal in ("measured", "estimated", "unavailable", "59%"):
            self.assertIn(signal, report)
        for path in README_FILES:
            text = path.read_text(encoding="utf-8")
            self.assertIn("59%", text, path.name)
            self.assertRegex(text, r"(?i)measured|实测")
            self.assertRegex(text, r"(?i)estimated|估算")
            self.assertRegex(text, r"(?i)unavailable|不可得")


if __name__ == "__main__":
    unittest.main(verbosity=2)
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
/opt/homebrew/bin/python3.13 -m unittest tests.test_benchmark -v
```

Expected: non-zero exit because the fixture and report do not exist.

- [ ] **Step 3: Add a schema-valid initial fixture**

Create `tests/fixtures/real-project-benchmark.json` with this exact shape;
replace only metric values and evidence labels after evidence collection:

```json
{
  "schema_version": 1,
  "run_date": "2026-08-02",
  "method": "existing_evidence_then_read_only_gap_probes",
  "privacy": "anonymous_aggregate_only",
  "categories": [
    {
      "id": "codebase",
      "sample_count": 1,
      "metrics": {
        "route": {"value": "sol_then_luna", "evidence": "measured"},
        "luna_workers": {"value": null, "evidence": "unavailable"},
        "waves": {"value": null, "evidence": "unavailable"},
        "verification": {"value": null, "evidence": "unavailable"},
        "final_review": {"value": null, "evidence": "unavailable"},
        "elapsed_seconds": {"value": null, "evidence": "unavailable"}
      }
    },
    {
      "id": "documentation",
      "sample_count": 1,
      "metrics": {
        "route": {"value": "sol_then_luna", "evidence": "measured"},
        "luna_workers": {"value": null, "evidence": "unavailable"},
        "waves": {"value": null, "evidence": "unavailable"},
        "verification": {"value": null, "evidence": "unavailable"},
        "final_review": {"value": null, "evidence": "unavailable"},
        "elapsed_seconds": {"value": null, "evidence": "unavailable"}
      }
    },
    {
      "id": "infrastructure",
      "sample_count": 1,
      "metrics": {
        "route": {"value": null, "evidence": "unavailable"},
        "luna_workers": {"value": null, "evidence": "unavailable"},
        "waves": {"value": null, "evidence": "unavailable"},
        "verification": {"value": null, "evidence": "unavailable"},
        "final_review": {"value": null, "evidence": "unavailable"},
        "elapsed_seconds": {"value": null, "evidence": "unavailable"}
      }
    }
  ],
  "cost": {
    "typical_workflow_saving_percent": {"value": 59, "evidence": "estimated"},
    "measured_workflow_saving_percent": {"value": null, "evidence": "unavailable"},
    "exact_per_model_usage_available": {"value": null, "evidence": "unavailable"}
  }
}
```

Do not run the benchmark test green yet; the missing report and README evidence
boundary must keep it RED until Task 4 supplies real evidence.

### Task 4: Collect and publish anonymous real-project evidence

**Files:**
- Modify: `tests/fixtures/real-project-benchmark.json`
- Create: `tests/real-project-benchmark.md`
- Test: `tests/test_benchmark.py`

- [ ] **Step 1: Create a local-only evidence directory**

Run:

```bash
benchmark_evidence_dir=$(mktemp -d /tmp/sol-luna-real-project-benchmark.XXXXXX)
printf '%s\n' "$benchmark_evidence_dir"
```

Record the exact path in the implementation commentary only. Do not add it to
Git, a business repository, or a committed document.

- [ ] **Step 2: Inspect existing completed task evidence first**

Use recent Codex thread summaries and read-only project state to select one
completed sample for each available anonymous category. For every candidate:

1. Verify it explicitly used Sol-controlled routing or classify it accurately.
2. Count observable Luna starts only from runtime activity, not from prose.
3. Count waves only when dependency order is observable.
4. Accept verification and final review only when the record includes exact
   evidence or a real artifact/diff that can be reconciled read-only.
5. Record elapsed seconds only from completed task timestamps.
6. Record exact model usage only when the runtime exposes it.

Write raw notes only under the temporary evidence directory. Do not copy
prompts, source code, credentials, repository names, thread IDs, or absolute
paths into the public fixture.

- [ ] **Step 3: Run only minimum read-only gap probes**

For any category with no defensible sample, run a bounded read-only task with:

```text
Objective: Audit one repository boundary and return one observable finding.
Write scope: None.
Do not touch: All files, configuration, external systems, accounts, and production.
Verification: Report inspected file classes and one falsifiable result; no writes.
Passing condition: Exact runtime identity is observable and the repository remains byte-for-byte unchanged.
```

Capture pre/post `git status --short` and `git diff --quiet` in the business
repository. If the repository is dirty before the probe, preserve the exact
preexisting status and require the post-probe status to match. If exact model,
effort, comparable scope, or no-write evidence is unavailable, stop and keep
the corresponding public metric `null` with evidence `unavailable`.

- [ ] **Step 4: Replace only evidence-supported fixture fields**

For each category, set measured values only when Steps 2 or 3 provide exact
evidence. Leave all unsupported values exactly as:

```json
{"value": null, "evidence": "unavailable"}
```

Do not calculate `measured_workflow_saving_percent` unless exact per-model usage
is available for a comparable scope. Keep `typical_workflow_saving_percent` at
59 with `estimated` evidence.

- [ ] **Step 5: Write the public benchmark report**

Create `tests/real-project-benchmark.md` with these exact sections:

```markdown
# Anonymous real-project benchmark

Date: 2026-08-02

## Method

Existing completed evidence was inspected first. New probes were allowed only
for material gaps and were read-only. No business repository was modified.

## Evidence classes

- `measured`: directly observable runtime, timestamp, diff, or verification evidence.
- `estimated`: calculated from published assumptions rather than exact task usage.
- `unavailable`: evidence was insufficient, incomparable, or not exposed.

## Anonymous categories

| Category | Route | Luna workers | Waves | Verification | Final review | Elapsed |
| --- | --- | ---: | ---: | --- | --- | ---: |
```

Populate the three category rows from the fixture. Use `unavailable` literally
for every null metric. Then add:

```markdown
## Cost result

The current headline remains an `estimated` 59%. An exact `measured` workflow
saving is `unavailable` unless comparable per-model usage is exposed.

## Privacy and limitations

The public result contains anonymous aggregate categories only. It excludes
project names, paths, repository URLs, prompts, source content, secrets,
credentials, and private task details. A measured routing or review result does
not turn an unavailable cost metric into a measured saving.
```

- [ ] **Step 6: Run the benchmark tests and inspect the public files manually**

Run:

```bash
/opt/homebrew/bin/python3.13 -m unittest tests.test_benchmark -v
rg -n '/Users/|[A-Za-z]:\\Users\\|project_name|project_path|repository_url|thread_id|prompt' \
  tests/fixtures/real-project-benchmark.json tests/real-project-benchmark.md
```

Expected: the unittest may still fail only on README evidence-boundary text
until Task 5; `rg` prints no lines.

### Task 5: Publish the benchmark boundary in both README files

**Files:**
- Modify: `README.md`
- Modify: `README.en.md`
- Test: `tests/test_benchmark.py`
- Test: `tests/test_readme.py`

- [ ] **Step 1: Add the Chinese benchmark section before detailed cost**

Insert this structure into `README.md`, replacing bracketed row cells with the
sanitized fixture values or the literal word `不可得`:

```markdown
## 真实项目基准

我们先复用了本地项目中已经完成的 Sol Luna 任务证据，只对证据缺口运行最少的
只读探针。公开结果仅保留匿名聚合类别；没有修改任何业务项目，也没有公开项目
名称、路径、代码、提示词或业务内容。

| 匿名类别 | 路由 | Luna 数量 | Wave | 验证 | Sol 终审 | 耗时 |
| --- | --- | ---: | ---: | --- | --- | ---: |
| 代码项目 | Sol → Luna（实测） | 不可得 | 不可得 | 不可得 | 不可得 | 不可得 |
| 文档项目 | Sol → Luna（实测） | 不可得 | 不可得 | 不可得 | 不可得 | 不可得 |
| 基础设施项目 | 不可得 | 不可得 | 不可得 | 不可得 | 不可得 | 不可得 |

证据分为 `measured（实测）`、`estimated（估算）` 和
`unavailable（不可得）`。当前 **59%** 仍属于 `estimated`；如果无法取得同范围
任务的精确分模型用量，就不会把它写成真实项目的 `measured` 成本节省。

完整方法与匿名结果见 [`tests/real-project-benchmark.md`](tests/real-project-benchmark.md)。
```

- [ ] **Step 2: Add the exact English peer section**

Insert the same table and facts into `README.en.md` using `Codebase`,
`Documentation`, and `Infrastructure`, while retaining the literal evidence
labels `measured`, `estimated`, and `unavailable`.

- [ ] **Step 3: Run benchmark and README contracts**

Run:

```bash
/opt/homebrew/bin/python3.13 -m unittest tests.test_benchmark tests.test_readme -v
```

Expected: all benchmark and README tests pass.

- [ ] **Step 4: Commit the benchmark and README evidence boundary**

```bash
git add README.md README.en.md tests/test_benchmark.py \
  tests/fixtures/real-project-benchmark.json tests/real-project-benchmark.md
git commit -m "test: add anonymous real-project Sol Luna benchmark"
```

### Task 6: Run full validation and publish the verified source

**Files:**
- Verify only: `.agents/skills/sol-luna/**`
- Verify only: `.codex/agents/*.toml`
- Verify only: all files changed by Tasks 1–5

- [ ] **Step 1: Run the full local suite**

Run:

```bash
/opt/homebrew/bin/python3.13 -m unittest discover -s tests -q
bash scripts/validate.sh
git diff --check
```

Expected: all tests pass, `Validation: PASS`, and `git diff --check` exits 0.

- [ ] **Step 2: Run Skill Creator validation from the installed or official source**

First try:

```bash
/opt/homebrew/bin/python3.13 \
  /Users/kin3/.codex/skills/.system/skill-creator/scripts/quick_validate.py \
  .agents/skills/sol-luna
```

If the Codex Desktop system-skill directory is temporarily absent, download the
same official `openai/skills` validator into a unique temporary virtual
environment, install only `PyYAML` there, run it, and delete that exact temporary
directory. Expected final output: `Skill is valid!`.

- [ ] **Step 3: Verify runtime installation did not drift**

Run:

```bash
diff -qr .agents/skills/sol-luna /Users/kin3/.agents/skills/sol-luna
cmp -s .codex/agents/sol-controller.toml /Users/kin3/.codex/agents/sol-controller.toml
cmp -s .codex/agents/luna-max-worker.toml /Users/kin3/.codex/agents/luna-max-worker.toml
```

Expected: no output and exit 0. README-only and benchmark changes do not require
a new global Skill installation when these checks pass.

- [ ] **Step 4: Inspect final scope and commit any validator-only remainder**

Run:

```bash
git status --short
git diff --stat HEAD~2..HEAD
git diff --name-only HEAD~2..HEAD
```

Only the approved README, benchmark, validator, installer-preflight, and test
files may appear. If any approved validator change remains uncommitted, commit:

```bash
git add scripts/validate.sh scripts/validate.ps1 scripts/install.ps1 \
  tests/test_installers.py tests/test_readme.py tests/test_contract.py
git commit -m "test: validate Chinese-first documentation layout"
```

- [ ] **Step 5: Push `main` and wait for Windows CI**

Run:

```bash
git push origin main
gh run list --commit "$(git rev-parse HEAD)" \
  --json databaseId,status,conclusion,workflowName,url --limit 10
```

Resolve and watch the matching Windows validation run with:

```bash
run_id=$(gh run list --commit "$(git rev-parse HEAD)" \
  --json databaseId --limit 1 --jq '.[0].databaseId')
gh run watch "$run_id" --exit-status
```

Expected: all `windows-latest` and `windows-2022`, PowerShell
5.1 and PowerShell 7 jobs pass.

- [ ] **Step 6: Final evidence check**

Run:

```bash
git status --short
test "$(git rev-parse HEAD)" = "$(git ls-remote origin refs/heads/main | awk '{print $1}')"
```

Expected: clean tracked worktree apart from the temporary visual-companion
directory, and local `HEAD` equals remote `main`. Stop the visual-companion
server and remove only its exact generated session directory before the final
clean-status claim.
