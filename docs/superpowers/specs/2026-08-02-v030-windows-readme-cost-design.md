# v0.3.0 Windows, documentation, and cost design

## Goal

Release `v0.3.0` as `yehyakin/codex-sol-luna`: keep the two-role runtime
unchanged, complete the Windows lifecycle, publish equivalent English and
Simplified Chinese documentation with repository-owned artwork, and explain
the economic benefit of assigning bounded execution to Luna without making a
guaranteed savings claim.

The runtime remains deliberately small:

```text
User -> Sol controls, assigns, and reviews -> Luna Max executes and verifies
```

The Skill remains `$sol-luna`; the agents remain `sol-controller` and
`luna-max-worker`.

## Non-goals

- Do not add Terra, permanent agent teams, dashboards, or a third runtime role.
- Do not route simple work through Luna merely to claim savings.
- Do not change `~/.codex/config.toml` or unrelated agents.
- Do not promise a fixed Luna worker count or guaranteed cost reduction.
- Do not treat a GitHub-hosted Windows Server runner as Windows 11 evidence.
- Do not rename historical migration identifiers that installers must still
  recognize.

## Repository and release naming

- Rename the GitHub repository from `codex-sol-luna-orchestrator` to
  `codex-sol-luna` after implementation and validation are complete.
- Move the local checkout to `/Users/kin3/Projects/codex-sol-luna` only after
  the remote rename is verified.
- Preserve repository identity, history, `main`, and existing tags.
- Update current links and names; retain the old name only in historical or
  migration contexts.
- Create `v0.3.0` only from the final validated `main` commit.

The dedicated repository-rename decision record remains authoritative for the
external rename and rollback procedure.

## Windows lifecycle

Windows support is native PowerShell, not a wrapper around Bash. The supported
matrix is:

- Windows 11 with Windows PowerShell 5.1 and PowerShell 7.x.
- Windows Server 2022 with Windows PowerShell 5.1 and PowerShell 7.x.
- GitHub Actions `windows-latest` plus pinned `windows-2022`; the hosted runners
  provide Server evidence only.

The repository will contain:

- `scripts/install.ps1`: validate the source, reject unsafe paths and reparse
  points, back up exact targets, migrate unmodified legacy installs, upgrade an
  existing v0.2 install, stage replacements, and roll back failures.
- `scripts/validate.ps1`: parse and validate the Skill metadata, YAML surface,
  TOML agent definitions, exact model/effort identities, repository structure,
  Markdown links, PowerShell syntax, forbidden residue, and sensitive data.
- `scripts/uninstall.ps1`: remove only checksum-matching owned targets and
  optionally restore the latest valid backup.
- `tests/windows-lifecycle.ps1`: exercise the lifecycle against a unique
  temporary `ORCHESTRATE_HOME`, including spaces in paths, repeated install,
  legacy migration, modified-target refusal, injected rollback, config and
  unrelated-agent preservation, uninstall, and restore.
- A GitHub Actions workflow that runs the Python contract suite and Windows
  lifecycle under both `powershell` and `pwsh`.

The implementation must remain compatible with PowerShell 5.1 syntax. It may
reuse the existing transactional Windows installer, but must not replace its
working safety checks with a new abstraction.

## Bilingual README and artwork

`README.md` is the complete English document and `README.zh-CN.md` is its
complete Simplified Chinese counterpart. Each starts with an explicit language
switch and follows the same section order:

1. repository-owned hero and concise positioning;
2. Sol -> Luna architecture image;
3. when to use and when not to use;
4. platform matrix and platform-specific quickstarts;
5. exact runtime identities and fail-closed behavior;
6. stages, file ownership, evidence, and correction behavior;
7. install, validate, uninstall, backup, and rollback;
8. transparent cost model;
9. repository layout, testing, limitations, prior art, and license.

The visuals are local SVG files under `docs/assets/`, require no external
fonts, images, scripts, or tracking, include accessible text alternatives, and
remain legible in GitHub light and dark themes. The README style borrows only
general conventions from strong GitHub projects: short positioning, visible
quickstart, language navigation, platform clarity, and product screenshots or
diagrams. It does not copy their prose or branding.

## Cost model

### Current price facts

The release-day sources of truth are the official [OpenAI API pricing
page](https://developers.openai.com/api/docs/pricing) and the official
[Codex/ChatGPT rate card](https://learn.chatgpt.com/docs/pricing). The following
snapshot was checked on 2026-08-02; prices must be rechecked before release.

Standard short-context API prices per one million tokens:

| Model | Input | Cached input | Cache write | Output |
| --- | ---: | ---: | ---: | ---: |
| GPT-5.6 Sol | $5.00 | $0.50 | $6.25 | $30.00 |
| GPT-5.6 Luna | $0.20 | $0.02 | $0.25 | $1.20 |

ChatGPT credits per one million tokens:

| Model | Input | Cached input | Output |
| --- | ---: | ---: | ---: |
| GPT-5.6 Sol | 125 | 12.5 | 750 |
| GPT-5.6 Luna | 5 | 0.5 | 30 |

Luna therefore costs 1/25 of Sol across these token categories. Moving an
otherwise identical worker-token segment from Sol to Luna reduces that segment
by 96%.

### Orchestrated estimate

The complete workflow also uses Sol for planning and review, and Luna may read
some repeated context. The public estimate uses:

```text
savings = delegated_share * (1 - luna_duplication / 25) - sol_overhead
```

The delegated share and Sol overhead are fractions of the all-Sol baseline
cost; Luna duplication is a multiplier applied to delegated token volume:

- `delegated_share`: work that an all-Sol run would have performed but Luna now
  performs;
- `luna_duplication`: Luna token volume relative to that delegated baseline;
- `sol_overhead`: additional Sol planning and review beyond the all-Sol
  baseline.

| Scenario | Delegated | Luna duplication | Added Sol overhead | Estimated saving |
| --- | ---: | ---: | ---: | ---: |
| Conservative | 50% | 125% | 10% | about 38% |
| Typical | 70% | 115% | 8% | about 59% |
| Execution-heavy | 85% | 110% | 7% | about 74% |

Example: an all-Sol short-context workload with 1M input and 0.1M output costs
$8.00 or 200 ChatGPT credits. Under the typical assumptions, the routed
equivalent is about $3.30 or 82.4 credits, a reduction of about 59%.

These are transparent scenarios, not benchmarks or guarantees. Direct tasks
claim 0% routing savings. Poor task decomposition, repeated retries, unusually
large Sol reviews, or low delegation can reduce or reverse the benefit. API
users may see dollar savings; subscription users primarily receive more usable
capacity unless the routing also avoids purchasing extra credits or a higher
plan.

## Test-first execution and ownership

Sol owns the plan and final review. Luna workers receive bounded, nonrecursive
packets with one-file/one-owner enforcement.

### Stage 1: RED contract

One Luna owns only the new or updated test files. It records failing tests for
missing Windows scripts, lifecycle behavior, README parity, images, naming,
cost facts, formulas, scenarios, and disclaimers. No production or README file
may be changed in this stage.

### Stage 2: parallel implementation

After Sol accepts the RED evidence, two Luna workers may run concurrently:

- Windows worker: owns only `scripts/install.ps1`, `scripts/validate.ps1`, and
  `scripts/uninstall.ps1`.
- Documentation worker: owns only `README.md`, `README.zh-CN.md`, the two SVG
  assets, and the v0.3 design/rename documentation assigned by Sol.

Their scopes do not overlap. Neither worker owns tests, CI, Skill runtime
files, agent TOML files, or global installed copies.

### Stage 3: integration and CI

One Luna owns only `scripts/validate.sh`, the GitHub Actions workflow, and the
Windows evidence record. It integrates the completed work, runs the full local
suite, and supplies CI evidence. Native Windows 11 results remain a separate
gate because GitHub-hosted runners are Windows Server.

### Stage 4: external rename and release

After Sol reviews the real diff and all evidence, the main Codex renames the
GitHub repository and local checkout, verifies repository identity and refs,
and then creates `v0.3.0`. External rename, tag, release, installation, and
push operations remain main-Codex responsibilities.

## Acceptance gates

- Skill Creator quick validation passes for `.agents/skills/sol-luna`.
- `bash scripts/validate.sh` and the full Python suite pass.
- `scripts/validate.ps1` and the Windows lifecycle suite pass on the required
  PowerShell editions and Windows environments.
- GitHub Actions is green for every declared matrix cell.
- Native Windows 11 evidence is real or the release is explicitly blocked; it
  is never inferred from Server CI.
- Both README versions have equivalent required content, valid links, valid
  local image targets, and the same cost assumptions and disclaimers.
- Official prices are rechecked on release day.
- The actual diff contains no overlapping ownership, unrelated changes,
  business-project names, credentials, or config overwrite.
- Sol returns `PASS`; one focused correction is allowed per failed task.
- The new canonical GitHub URL, remote, checkout path, tag, release, installed
  copies, and fresh-session discovery are verified before completion is
  reported.
