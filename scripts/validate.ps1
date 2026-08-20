#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-Condition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function Get-Text {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Assert-Regex {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if ($Text -notmatch $Pattern) { throw $Message }
}

function Get-Frontmatter {
    param([Parameter(Mandatory = $true)][string]$Path)
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    Assert-Condition ($lines.Count -ge 4 -and $lines[0] -eq "---") "invalid Skill frontmatter opener"
    $closing = -1
    for ($index = 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -eq "---") { $closing = $index; break }
    }
    Assert-Condition ($closing -gt 1) "invalid Skill frontmatter closer"
    $result = @{}
    for ($index = 1; $index -lt $closing; $index++) {
        if ([string]::IsNullOrWhiteSpace($lines[$index])) { continue }
        Assert-Condition ($lines[$index] -match "^(?<key>[a-z_]+):\s*(?<value>.+)$") "invalid Skill frontmatter line"
        Assert-Condition (-not $result.ContainsKey($Matches.key)) "duplicate Skill frontmatter key"
        $result[$Matches.key] = $Matches.value.Trim().Trim('"')
    }
    Assert-Condition ($result.Count -eq 2 -and $result.ContainsKey("name") -and $result.ContainsKey("description")) "Skill frontmatter must contain only name and description"
    return $result
}

$requiredFiles = @(
    ".agents/skills/codex-prove/SKILL.md",
    ".agents/skills/codex-prove/agents/openai.yaml",
    ".agents/skills/codex-prove/references/orchestration.md",
    ".agents/skills/codex-prove/references/runtime-notes.md",
    ".agents/skills/sol-control/SKILL.md",
    ".agents/skills/sol-control/agents/openai.yaml",
    ".codex/agents/prove-controller.toml",
    ".codex/agents/prove-complex-worker.toml",
    ".codex/agents/prove-efficient-worker.toml",
    "scripts/install.sh",
    "scripts/validate.sh",
    "scripts/uninstall.sh",
    "scripts/install.ps1",
    "scripts/validate.ps1",
    "scripts/uninstall.ps1",
    "scripts/test.sh",
    "scripts/benchmark_ab.py",
    "README.md",
    "README.en.md",
    "CONTRIBUTING.md",
    "CODE_OF_CONDUCT.md",
    "SECURITY.md",
    "SUPPORT.md",
    ".github/ISSUE_TEMPLATE/bug_report.yml",
    ".github/ISSUE_TEMPLATE/feature_request.yml",
    ".github/ISSUE_TEMPLATE/config.yml",
    ".github/pull_request_template.md",
    "tests/windows-lifecycle.ps1",
    "tests/fixtures/forward-cases.json",
    "tests/fixtures/v100-ab-benchmark.json",
    "tests/v100-ab-benchmark.md",
    "tests/v100-live-smoke.md",
    "tests/test_v100_benchmark.py",
    "tests/test_v100_evidence_control.py",
    "CODEX_PROVE_V1_IMPLEMENTATION_REPORT.md",
    ".github/workflows/windows-validation.yml",
    ".github/workflows/posix-validation.yml",
    "NOTICE",
    "LICENSE"
)
foreach ($relative in $requiredFiles) {
    $path = Join-Path $repoRoot $relative
    Assert-Condition (Test-Path -LiteralPath $path -PathType Leaf) "missing required file: $relative"
}

foreach ($relative in @(
    ".agents/skills/sol-luna",
    ".agents/skills/orchestrate-sol-luna",
    ".codex/agents/sol-controller.toml",
    ".codex/agents/terra-high-worker.toml",
    ".codex/agents/luna-max-worker.toml",
    ".codex/agents/sol-planner.toml"
)) {
    Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relative))) "legacy runtime source remains: $relative"
}

$skillPath = Join-Path $repoRoot ".agents/skills/codex-prove/SKILL.md"
$skillMeta = Get-Frontmatter $skillPath
Assert-Condition ($skillMeta.name -eq "codex-prove") "canonical Skill name is invalid"
Assert-Condition ($skillMeta.description.StartsWith("Use only when") -and $skillMeta.description.Contains('$codex-prove')) "canonical Skill description is invalid"

$compatSkillPath = Join-Path $repoRoot ".agents/skills/sol-control/SKILL.md"
$compatMeta = Get-Frontmatter $compatSkillPath
Assert-Condition ($compatMeta.name -eq "sol-control" -and $compatMeta.description.Contains('$sol-control')) "compatibility Skill frontmatter is invalid"

$skillText = Get-Text $skillPath
$contractText = Get-Text (Join-Path $repoRoot ".agents/skills/codex-prove/references/orchestration.md")
$runtimeText = Get-Text (Join-Path $repoRoot ".agents/skills/codex-prove/references/runtime-notes.md")
$combined = $skillText + "`n" + $contractText + "`n" + $runtimeText
foreach ($marker in @(
    "Planning", "Routing", "Ownership", "Verification", "Evidence",
    "Requirement ID", "one owner", "Native Nested", "Compatibility",
    'fork_turns="none"', "Fail Closed", "PASS | FIX | BLOCKED",
    "prove-controller", "prove-complex-worker", "prove-efficient-worker"
)) {
    Assert-Condition ($combined.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) "orchestration contract is missing: $marker"
}

$openaiText = Get-Text (Join-Path $repoRoot ".agents/skills/codex-prove/agents/openai.yaml")
foreach ($pattern in @(
    '(?m)^interface:\s*$',
    '(?m)^\s{2}display_name:\s*"Codex PROVE"\s*$',
    '(?m)^\s{2}short_description:\s*"[^"\r\n]{25,64}"\s*$',
    '(?m)^\s{2}default_prompt:\s*".*\$codex-prove.*"\s*$',
    '(?m)^policy:\s*$',
    '(?m)^\s{2}allow_implicit_invocation:\s*false\s*$'
)) {
    Assert-Regex $openaiText $pattern "canonical openai.yaml is invalid"
}

$compatText = Get-Text (Join-Path $repoRoot ".agents/skills/sol-control/agents/openai.yaml")
Assert-Regex $compatText '\$sol-control' "compatibility openai.yaml misses old invocation"
Assert-Regex $compatText '\$codex-prove' "compatibility openai.yaml misses canonical invocation"
Assert-Regex $compatText '(?m)^\s{2}allow_implicit_invocation:\s*false\s*$' "compatibility openai.yaml permits implicit invocation"

$agentExpectations = @(
    @(".codex/agents/prove-controller.toml", "prove-controller", "gpt-5.6-sol", "high", "read-only", $false),
    @(".codex/agents/prove-complex-worker.toml", "prove-complex-worker", "gpt-5.6-terra", "high", "workspace-write", $true),
    @(".codex/agents/prove-efficient-worker.toml", "prove-efficient-worker", "gpt-5.6-luna", "max", "workspace-write", $true)
)
foreach ($expectation in $agentExpectations) {
    $text = Get-Text (Join-Path $repoRoot $expectation[0])
    Assert-Regex $text ('(?m)^name\s*=\s*"' + [regex]::Escape($expectation[1]) + '"\s*$') "agent name is invalid"
    Assert-Regex $text ('(?m)^model\s*=\s*"' + [regex]::Escape($expectation[2]) + '"\s*$') "agent model is invalid"
    Assert-Regex $text ('(?m)^model_reasoning_effort\s*=\s*"' + [regex]::Escape($expectation[3]) + '"\s*$') "agent reasoning effort is invalid"
    Assert-Regex $text ('(?m)^sandbox_mode\s*=\s*"' + [regex]::Escape($expectation[4]) + '"\s*$') "agent sandbox is invalid"
    Assert-Regex $text '(?s)developer_instructions\s*=\s*""".+"""' "agent instructions are missing"
    if ($expectation[5]) { Assert-Regex $text '(?is)do not .*?(spawn|create).*?subagent' "worker can create subagents" }
}

foreach ($script in @(
    "scripts/install.ps1",
    "scripts/validate.ps1",
    "scripts/uninstall.ps1",
    "tests/windows-lifecycle.ps1"
)) {
    $path = Join-Path $repoRoot $script
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
    Assert-Condition ($errors.Count -eq 0) "PowerShell syntax failed: $script"
}

$forwardCases = Get-Content -LiteralPath (Join-Path $repoRoot "tests/fixtures/forward-cases.json") -Raw | ConvertFrom-Json
Assert-Condition ($forwardCases.Count -ge 13) "forward test fixture is incomplete"
$benchmark = Get-Content -LiteralPath (Join-Path $repoRoot "tests/fixtures/v100-ab-benchmark.json") -Raw | ConvertFrom-Json
Assert-Condition ($null -ne $benchmark) "benchmark fixture is invalid"

$credentialPatterns = @(
    'AKIA[0-9A-Z]{16}',
    '-----BEGIN [A-Z0-9 ]+ PRIVATE KEY-----',
    'gh[pousr]_[A-Za-z0-9_]{20,}',
    'sk-[A-Za-z0-9]{20,}',
    'xox[baprs]-[A-Za-z0-9-]{20,}'
)
Get-ChildItem -LiteralPath $repoRoot -File -Recurse -Force | Where-Object {
    $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.FullName -notmatch '[\\/]__pycache__[\\/]'
} | ForEach-Object {
    try { $text = Get-Text $_.FullName } catch { return }
    foreach ($pattern in $credentialPatterns) {
        if ($text -match $pattern) { throw "possible credential detected" }
    }
    if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) { throw "missing final newline: $($_.FullName)" }
    foreach ($line in ($text -split "`n")) {
        if ($line -match '[ \t]\r?$') { throw "trailing whitespace: $($_.FullName)" }
    }
}

foreach ($forbidden in @("IPZOR", "Buzz", "DeepSeek", "OpenPencil")) {
    foreach ($path in @(
        (Join-Path $repoRoot ".agents/skills/codex-prove"),
        (Join-Path $repoRoot ".agents/skills/sol-control")
    )) {
        Get-ChildItem -LiteralPath $path -File -Recurse | ForEach-Object {
            Assert-Condition ((Get-Text $_.FullName) -notmatch [regex]::Escape($forbidden)) "project-specific term remains in Skill"
        }
    }
}

foreach ($activeFile in @("README.md", "README.en.md", "SECURITY.md", "CONTRIBUTING.md", "SUPPORT.md", ".github/ISSUE_TEMPLATE/config.yml")) {
    Assert-Condition ((Get-Text (Join-Path $repoRoot $activeFile)) -notmatch 'github\.com/yehyakin/codex-sol-control') "old repository URL remains in active documentation"
}

Write-Output "PowerShell syntax: PASS"
Write-Output "YAML/TOML/JSON structure: PASS"
Write-Output "Validation: PASS"
exit 0
