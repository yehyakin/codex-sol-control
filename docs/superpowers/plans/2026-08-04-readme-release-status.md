# README Release Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a compact, evidence-bound v0.3.0 release-status block to both READMEs, verify the exact candidate on POSIX and Windows, then merge and push it to `main`.

**Architecture:** Extend the existing bilingual first-screen surface without changing its cost-first layout or artwork. Reuse the existing README parity test so the suite remains 106 tests, bind public links to the already green report commit `6895f06`, and require the final README commit plus the merged `main` result to pass their own checks.

**Tech Stack:** Markdown, Python 3.11+ `unittest`, Bash validation scripts, Git, GitHub Actions, GitHub CLI.

---

### Task 1: Add a RED bilingual release-status contract

**Files:**
- Modify: `tests/test_readme.py:801-831`
- Test: `tests/test_readme.py`

- [ ] **Step 1: Extend the existing parity signal list**

Add these exact entries to `parity_signals` in
`test_bilingual_core_signals_have_parity`:

```python
            "v0.3.0",
            "106/106",
            "Compatibility",
            "Native Nested",
            "6895f06",
            "ORCHESTRATE_SOL_LUNA_V2_IMPLEMENTATION_REPORT.md",
            "actions/runs/30858707335",
            "actions/runs/30858707364",
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 /opt/homebrew/bin/python3.13 -B \
  -m unittest tests.test_readme.ReadmeContractTests.test_bilingual_core_signals_have_parity -v
```

Expected: exit 1 because both READMEs are missing at least `v0.3.0`.

### Task 2: Add the bilingual release-status block

**Files:**
- Modify: `README.md:20-23`
- Modify: `README.en.md:23-26`
- Test: `tests/test_readme.py`

- [ ] **Step 1: Add the Chinese status block**

Insert this exact block after the `$sol-luna` invocation paragraph and before
the Control Orbit image in `README.md`:

```markdown
### v0.3.0 发布状态

| 验证面 | 结果 |
| --- | --- |
| 本地仓库 | Skill Creator **PASS**；**106/106** tests PASS |
| 托管 CI | POSIX **PASS**；Windows Server 2022 / `windows-latest` × Windows PowerShell 5.1 / PowerShell 7 **PASS** |
| 编排模式 | **Compatibility 已验证**；Native Nested、全新 CLI child model/effort 身份与物理 Windows 11 尚未证明 |

证据绑定报告提交 `6895f06`：[POSIX CI](https://github.com/yehyakin/codex-sol-luna/actions/runs/30858707335) · [Windows CI](https://github.com/yehyakin/codex-sol-luna/actions/runs/30858707364) · [完整实施报告](ORCHESTRATE_SOL_LUNA_V2_IMPLEMENTATION_REPORT.md)
```

- [ ] **Step 2: Add the English peer block**

Insert this exact block in the matching position in `README.en.md`:

```markdown
### v0.3.0 release status

| Verification surface | Result |
| --- | --- |
| Local repository | Skill Creator **PASS**; **106/106** tests PASS |
| Hosted CI | POSIX **PASS**; Windows Server 2022 / `windows-latest` × Windows PowerShell 5.1 / PowerShell 7 **PASS** |
| Orchestration mode | **Compatibility verified**; Native Nested, fresh-CLI child model/effort identity, and physical Windows 11 remain unproven |

Evidence is bound to report commit `6895f06`: [POSIX CI](https://github.com/yehyakin/codex-sol-luna/actions/runs/30858707335) · [Windows CI](https://github.com/yehyakin/codex-sol-luna/actions/runs/30858707364) · [full implementation report](ORCHESTRATE_SOL_LUNA_V2_IMPLEMENTATION_REPORT.md)
```

- [ ] **Step 3: Run the focused test and confirm GREEN**

Run the Task 1 focused command again.

Expected: one test PASS, exit 0.

- [ ] **Step 4: Run all README tests**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 /opt/homebrew/bin/python3.13 -B \
  -m unittest tests.test_readme -v
```

Expected: every README contract test PASS, exit 0.

- [ ] **Step 5: Commit the README contract and content together**

```bash
git add -- README.md README.en.md tests/test_readme.py
git diff --cached --check
git commit -m "docs: publish verified v0.3.0 release status"
```

Expected: one commit containing exactly the two READMEs and the parity test.

### Task 3: Validate and publish the final feature candidate

**Files:**
- Verify: `README.md`
- Verify: `README.en.md`
- Verify: `tests/test_readme.py`
- Verify: repository-wide validation surfaces

- [ ] **Step 1: Run local release gates**

```bash
bash scripts/test.sh
bash scripts/validate.sh
git diff --check
git status --short --branch
```

Expected: 106 tests PASS, validation PASS, no diff errors, and a clean feature
branch ahead of its remote only by the design/plan/README commits.

- [ ] **Step 2: Push the feature branch**

```bash
git push -u origin codex/terra-tiered-routing
```

Expected: remote feature branch advances to the local HEAD without force push.

- [ ] **Step 3: Wait for the exact feature HEAD workflows**

```bash
release_head=$(git rev-parse HEAD)
gh run list --branch codex/terra-tiered-routing --commit "$release_head" \
  --json databaseId,name,status,conclusion,headSha,url
for run_id in $(gh run list --branch codex/terra-tiered-routing \
  --commit "$release_head" --json databaseId --jq '.[].databaseId'); do
  gh run watch "$run_id" --exit-status
done
```

Expected: POSIX success and all four Windows jobs success on `release_head`.

### Task 4: Merge the verified candidate to main

**Files:**
- Merge: complete `codex/terra-tiered-routing` history into `main`
- Preserve: remote `codex/terra-tiered-routing` branch

- [ ] **Step 1: Recheck merge safety**

```bash
git fetch origin --prune
git status --short --branch
git merge-tree --write-tree origin/main codex/terra-tiered-routing
git rev-list --left-right --count origin/main...codex/terra-tiered-routing
```

Expected: clean worktree, merge-tree exit 0 with no conflict, feature branch
behind count 0.

- [ ] **Step 2: Merge with an auditable merge commit**

```bash
git checkout main
git pull --ff-only origin main
git merge --no-ff codex/terra-tiered-routing \
  -m "Merge Terra tiered routing and README release status"
```

Expected: merge completes without conflict and preserves the feature commits.

- [ ] **Step 3: Verify the merged result before push**

```bash
bash scripts/test.sh
bash scripts/validate.sh
git diff --check
git status --short --branch
```

Expected: 106 tests PASS, validation PASS, no diff errors, and clean `main`
ahead of `origin/main` by the merge.

- [ ] **Step 4: Push main and verify the remote**

```bash
git push origin main
main_head=$(git rev-parse HEAD)
git ls-remote origin refs/heads/main
gh run list --branch main --commit "$main_head" \
  --json databaseId,name,status,conclusion,headSha,url
```

Expected: remote `main` equals `main_head`. Wait for the POSIX and Windows runs
on `main_head`; both must finish with `success`.

- [ ] **Step 5: Leave the feature branch intact**

Do not delete the local or remote `codex/terra-tiered-routing` branch. Report
the merge commit, final CI URLs, README paths, and remaining Native
Nested/fresh-CLI/physical-Windows-11 limitations.
