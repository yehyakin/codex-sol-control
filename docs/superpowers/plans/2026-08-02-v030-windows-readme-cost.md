# v0.3.0 Windows, README, and Cost Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `$sol-luna`. Sol owns the stage graph, file ownership, and review. Luna Max workers execute only the bounded packets below and return exact evidence.

**Goal:** Release `codex-sol-luna` v0.3.0 with a safe native Windows lifecycle, equivalent illustrated English and Chinese documentation, and a sourced, assumption-based Sol/Luna cost estimate.

**Architecture:** Preserve the existing two-role Skill unchanged. Establish RED contract tests first, then run the Windows script work and README/artwork work in parallel because their write scopes do not overlap. Integrate validation and CI only after both pass, then let Sol audit the real diff before the main Codex performs the GitHub rename and release.

**Tech Stack:** Markdown, SVG 1.1, Bash, Python 3.13 `unittest`, Windows PowerShell 5.1, PowerShell 7.x, GitHub Actions, Git/GitHub CLI.

---

## File map and ownership

| Owner | Files | Responsibility |
| --- | --- | --- |
| Luna tests | `tests/test_contract.py`, `tests/test_installers.py`, `tests/test_readme.py`, `tests/windows-lifecycle.ps1` | RED contracts and isolated lifecycle checks |
| Luna Windows | `scripts/install.ps1`, `scripts/validate.ps1`, `scripts/uninstall.ps1` | Native PowerShell lifecycle |
| Luna docs | `README.md`, `README.zh-CN.md`, `docs/assets/sol-luna-hero.svg`, `docs/assets/sol-luna-architecture.svg`, approved design records | Bilingual user documentation and local visuals |
| Luna integration | `scripts/validate.sh`, `.github/workflows/windows-validation.yml`, `docs/validation/v0.3.0-windows.md` | Cross-platform validation, CI, and evidence |
| Main Codex | GitHub name, `origin`, local checkout path, global install, tag, release | External mutations and final integration |

One file has one owner for the entire run. `.agents/skills/sol-luna/**` and
`.codex/agents/**` are read-only because the v0.3 work does not change runtime
behavior or identities.

### Task 1: Establish the RED release contract

**Files:**
- Modify: `tests/test_contract.py`
- Modify: `tests/test_installers.py`
- Create: `tests/test_readme.py`
- Create: `tests/windows-lifecycle.ps1`

- [ ] **Step 1: Extend required-file contracts**

Add assertions for these exact paths:

```python
for relative in (
    "README.zh-CN.md",
    "docs/assets/sol-luna-hero.svg",
    "docs/assets/sol-luna-architecture.svg",
    "scripts/validate.ps1",
    "scripts/uninstall.ps1",
    "tests/windows-lifecycle.ps1",
    ".github/workflows/windows-validation.yml",
):
    self.assertTrue((ROOT / relative).is_file(), relative)
```

- [ ] **Step 2: Encode README parity and cost facts**

Create `tests/test_readme.py` with `unittest` checks that both README files
contain the language switch, local SVG paths, `$sol-luna`, both runtime agent
names, macOS/Linux and Windows commands, official pricing links, `1/25`, `96%`,
`38%`, `59%`, `74%`, Direct-task `0%`, the API-versus-subscription distinction,
and a non-guarantee disclaimer. Parse Markdown link targets and assert every
relative target exists under the repository root. Parse both SVG files with
`xml.etree.ElementTree.parse`.

- [ ] **Step 3: Encode the PowerShell lifecycle**

Create a dependency-free `tests/windows-lifecycle.ps1` with strict mode, a
unique temporary `ORCHESTRATE_HOME`, SHA-256 snapshot helpers, and assertions
for these sequences:

```powershell
& $Install
& $Validate
& $Install
& $Uninstall
& $Install
& $Uninstall -RestoreLatest
```

Seed separate temporary homes for an unmodified v0.1 install, modified legacy
targets, an existing v0.2 install, a path containing spaces, a modified current
target, and `ORCHESTRATE_FAILPOINT=after-replace`. Assert `config.toml` and an
unrelated `keep-me.toml` retain their original SHA-256 hashes in every case.
Always remove only the unique test directory in `finally`.

- [ ] **Step 4: Prove RED without contaminating production files**

Run:

```bash
/opt/homebrew/bin/python3.13 -m unittest discover -s tests -v
git diff --check
```

Expected: Python fails only because the v0.3 README, SVG, PowerShell lifecycle,
and workflow files do not yet exist; `git diff --check` exits 0. If `pwsh` or
`powershell.exe` is present, also run the new lifecycle script and record the
expected missing-script failure.

- [ ] **Step 5: Commit the RED contract**

```bash
git add tests/test_contract.py tests/test_installers.py tests/test_readme.py tests/windows-lifecycle.ps1
git commit -m "test: define v0.3 windows and documentation contract"
```

### Task 2: Complete the native Windows lifecycle

**Files:**
- Modify: `scripts/install.ps1`
- Create: `scripts/validate.ps1`
- Create: `scripts/uninstall.ps1`
- Test: `tests/windows-lifecycle.ps1`

- [ ] **Step 1: Keep the existing transactional installer and close gaps**

Retain its literal-path, reparse-point, digest, backup, migration, staging, and
rollback helpers. Add the new PowerShell files and bilingual README to source
validation. Invoke `scripts/validate.ps1` before the first mutation. Preserve
the version-2 install-state schema unless its data shape changes. Treat the
release number and install-state schema as separate values.

- [ ] **Step 2: Implement native validation**

`scripts/validate.ps1` must run under PowerShell 5.1 and 7.x and return nonzero
on any failure. Use `Get-Content -Raw`, .NET XML parsing, exact regex checks,
`Test-Path -LiteralPath`, and an available TOML parser path; do not use
PowerShell-7-only operators. Check repository structure, Skill frontmatter,
`openai.yaml`, agent names/models/efforts/sandboxes, Luna non-recursion,
Markdown relative links, SVG XML, forbidden business terms, obvious secret
patterns, and PowerShell parsing through:

```powershell
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    $Path,
    [ref]$null,
    [ref]$errors
) | Out-Null
if ($errors.Count -ne 0) { throw "PowerShell syntax validation failed" }
```

- [ ] **Step 3: Implement checksum-protected uninstall and restore**

`scripts/uninstall.ps1` accepts `[switch]$RestoreLatest`. Resolve only the exact
three owned targets and the exact `.codex/sol-luna/install-state`. Refuse a
filesystem root, reparse point, invalid backup ID, incomplete state, or changed
target digest. Move targets to a transaction directory before final removal;
on error, move every target back. Restore only the latest valid recorded backup
and never edit `config.toml` or unrelated agents.

- [ ] **Step 4: Run the Windows lifecycle on both editions**

On Windows Server 2022 and Windows 11, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/validate.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/windows-lifecycle.ps1
pwsh -NoProfile -File scripts/validate.ps1
pwsh -NoProfile -File tests/windows-lifecycle.ps1
```

Expected: every command exits 0; all writes remain within the printed temporary
home; config and unrelated-agent hashes match their pre-test values.

- [ ] **Step 5: Commit Windows lifecycle code**

```bash
git add scripts/install.ps1 scripts/validate.ps1 scripts/uninstall.ps1
git commit -m "feat: complete native Windows lifecycle"
```

### Task 3: Publish bilingual documentation and local visuals

**Files:**
- Modify: `README.md`
- Create: `README.zh-CN.md`
- Create: `docs/assets/sol-luna-hero.svg`
- Create: `docs/assets/sol-luna-architecture.svg`
- Modify: `docs/superpowers/specs/2026-08-02-repository-rename-design.md`
- Modify: `docs/superpowers/specs/2026-08-02-v030-windows-readme-cost-design.md`
- Test: `tests/test_readme.py`

- [ ] **Step 1: Create repository-owned SVGs**

Use SVG view boxes, system fonts, high-contrast text, no scripts, no remote
references, and `<title>` plus `<desc>`. The hero communicates “Sol controls;
Luna Max executes.” The architecture image shows User -> Sol -> parallel,
non-overlapping Luna workers -> Sol review -> Main Codex delivery.

- [ ] **Step 2: Rebuild the English README**

Use this order: language navigation, hero, one-sentence value, quickstart,
architecture, use/not-use, runtime identities, stages and ownership, platform
matrix, install/validate/uninstall/restore, fail-closed safety, cost, repository
layout, validation, limitations, prior art, license. Use the canonical target
URL `https://github.com/yehyakin/codex-sol-luna` for current links.

- [ ] **Step 3: Create full Chinese parity**

Translate the complete user-facing content rather than summarizing it. Keep
commands, identifiers, paths, prices, formula inputs, scenario values, sources,
and warnings semantically identical. Link the two READMEs to each other at the
top.

- [ ] **Step 4: State the cost model exactly**

Link `https://developers.openai.com/api/docs/pricing` and
`https://learn.chatgpt.com/docs/pricing`, mark the 2026-08-02 snapshot, list the
Sol/Luna rate rows, and show:

```text
savings = delegated_share * (1 - luna_duplication / 25) - sol_overhead
```

Publish 38%, 59%, and 74% as scenario estimates only. State that the identical
delegated worker segment is 96% cheaper, Direct claims 0%, retries can erase
savings, API savings are monetary, and subscriptions primarily gain capacity.

- [ ] **Step 5: Verify and commit docs**

```bash
/opt/homebrew/bin/python3.13 -m unittest tests.test_readme -v
git diff --check
git add README.md README.zh-CN.md docs/assets docs/superpowers/specs
git commit -m "docs: publish bilingual v0.3 guide"
```

Expected: all README tests pass, both SVGs parse, all relative links resolve,
and whitespace validation exits 0.

### Task 4: Integrate validation and Windows CI

**Files:**
- Modify: `scripts/validate.sh`
- Create: `.github/workflows/windows-validation.yml`
- Create: `docs/validation/v0.3.0-windows.md`
- Test: all files under `tests/`

- [ ] **Step 1: Extend Unix validation**

Require the new README, SVG, PowerShell, lifecycle-test, and workflow files.
Retain Python TOML/YAML/Markdown checks and deterministic PowerShell structure
checks for macOS hosts without PowerShell. When `pwsh` exists, parse and run
`scripts/validate.ps1` rather than treating structural checks as native proof.

- [ ] **Step 2: Add the Windows workflow**

Trigger on pull requests, pushes to `main`, and manual dispatch. Use
`windows-latest` and `windows-2022`; in each job run the Python suite, then run
`scripts/validate.ps1` and `tests/windows-lifecycle.ps1` once with
`powershell` and once with `pwsh`. Upload concise logs without home contents or
configuration bodies.

- [ ] **Step 3: Record exact evidence**

`docs/validation/v0.3.0-windows.md` records commit SHA, GitHub run URL, runner
image/OS build, `$PSVersionTable.PSVersion`, command, exit code, and whether the
evidence is Server or native Windows 11. It contains no token, environment
variable value, user config, or temporary-home content.

- [ ] **Step 4: Run the complete local gate**

```bash
bash scripts/validate.sh
/opt/homebrew/bin/python3.13 -m unittest discover -s tests -v
python3 /Users/kin3/.codex/skills/.system/skill-creator/scripts/quick_validate.py .agents/skills/sol-luna
git diff --check
```

Expected: all commands exit 0. Then push the branch and require every Windows
matrix cell to pass before recording CI as successful.

- [ ] **Step 5: Commit integration**

```bash
git add scripts/validate.sh .github/workflows/windows-validation.yml docs/validation/v0.3.0-windows.md
git commit -m "ci: validate the Windows lifecycle"
```

### Task 5: Sol final review, rename, install, and release

**Files and external state:**
- GitHub repository name
- Git `origin`
- Local checkout directory
- Global installed Skill and two agent copies
- Git tag and GitHub release `v0.3.0`

- [ ] **Step 1: Sol reviews the real result**

Give Sol the original request, plan, Luna results, full `git diff main...HEAD`,
changed-path list, local test outputs, Windows CI run, native Windows 11
evidence, price recheck, and dirty-worktree state. Sol returns `PASS`, one
bounded `FIX`, or `BLOCKED`. Do not perform the rename on `FIX` or `BLOCKED`.

- [ ] **Step 2: Recheck external invariants**

Record GitHub repository ID, default branch, `main` SHA, current branch SHA,
and dereferenced `v0.1.0` and `v0.2.0` SHAs. Confirm
`yehyakin/codex-sol-luna` does not already exist. Confirm official prices still
match the README or update the docs through their existing owner and rerun all
gates.

- [ ] **Step 3: Rename without history rewriting**

Rename the GitHub repository, update `origin`, fetch, and compare all recorded
IDs and refs. Move the checkout to `/Users/kin3/Projects/codex-sol-luna` only
after the new canonical URL resolves. Verify the old URL redirects. Never
force-push, rewrite a tag, or delete the old checkout as recovery logic.

- [ ] **Step 4: Install and verify discovery**

Back up current global targets, run the validated macOS installer from the new
checkout, compare installed checksums with repository source, and open a fresh
Codex task to confirm `$sol-luna`, `sol-controller`, and `luna-max-worker` are
discoverable with exact runtime identities.

- [ ] **Step 5: Tag and publish**

Only with a clean worktree, green CI, native Windows 11 evidence, fresh-session
discovery, and Sol `PASS`:

```bash
git tag -a v0.3.0 -m "codex-sol-luna v0.3.0"
git push origin main v0.3.0
gh release create v0.3.0 --repo yehyakin/codex-sol-luna --verify-tag --title "codex-sol-luna v0.3.0" --notes-from-tag
```

Expected: `main`, `origin/main`, and `v0.3.0^{}` resolve to the same commit;
the GitHub release is published from that exact tag; the final report states
any remaining limitation without weakening a failed gate.
