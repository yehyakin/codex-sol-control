#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-ReparsePoint {
    param([Parameter(Mandatory = $true)]$Item)
    return (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Test-PathExists {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [bool](Test-Path -LiteralPath $Path)
}

function Assert-PlainTree {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-PathExists $Path)) {
        throw "Validation: missing path: $Path"
    }
    $rootItem = Get-Item -LiteralPath $Path -Force
    if (Test-ReparsePoint $rootItem) {
        throw "Validation: reparse point is not allowed: $Path"
    }
    if ($rootItem.PSIsContainer) {
        foreach ($item in @(Get-ChildItem -LiteralPath $Path -Force -Recurse)) {
            if (Test-ReparsePoint $item) {
                throw "Validation: reparse point is not allowed in: $Path"
            }
        }
    }
}

function Assert-File {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Validation: missing required file: $Path"
    }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer -or (Test-ReparsePoint $item)) {
        throw "Validation: unsafe required file: $Path"
    }
}

function Read-Utf8Text {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8)
}

function Assert-Regex {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if ($Text -notmatch $Pattern) {
        throw "Validation: $Message"
    }
}

function Assert-TomlAgents {
    param(
        [Parameter(Mandatory = $true)][string]$SolPath,
        [Parameter(Mandatory = $true)][string]$LunaPath,
        [Parameter(Mandatory = $true)][string]$TerraPath
    )

    $pythonCode = @'
import re
import sys
import tomllib

sol_path, luna_path, terra_path = sys.argv[1:4]
expected = {
    sol_path: {
        "name": "sol-controller",
        "model": "gpt-5.6-sol",
        "model_reasoning_effort": "high",
        "sandbox_mode": "read-only",
    },
    luna_path: {
        "name": "luna-max-worker",
        "model": "gpt-5.6-luna",
        "model_reasoning_effort": "max",
        "sandbox_mode": "workspace-write",
    },
    terra_path: {
        "name": "terra-high-worker",
        "model": "gpt-5.6-terra",
        "model_reasoning_effort": "high",
        "sandbox_mode": "workspace-write",
    },
}

for path, fields in expected.items():
    with open(path, "rb") as handle:
        data = tomllib.load(handle)
    for key, value in fields.items():
        if data.get(key) != value:
            raise SystemExit(1)
    instructions = data.get("developer_instructions")
    if not isinstance(instructions, str) or not instructions.strip():
        raise SystemExit(1)
    if path in (luna_path, terra_path) and not re.search(
        r"do not (?:spawn|create).*subagent", instructions, re.IGNORECASE | re.DOTALL
    ):
        raise SystemExit(1)
'@

    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("toml-agents-" + [System.Guid]::NewGuid().ToString("N") + ".py")
    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($tempPath, $pythonCode, $utf8NoBom)

        $candidates = @("python", "python3", "py")
        foreach ($candidateName in $candidates) {
            $command = Get-Command $candidateName -CommandType Application -ErrorAction SilentlyContinue
            if ($null -eq $command) {
                continue
            }
            $arguments = @()
            if ($candidateName -eq "py") {
                $arguments += "-3"
            }
            $arguments += @($tempPath, $SolPath, $LunaPath, $TerraPath)
            try {
                & $command.Source @arguments *> $null
                if ($LASTEXITCODE -eq 0) {
                    return
                }
            }
            catch {
                # Try the next available Python command. The final error is explicit.
            }
        }

        throw "Validation: Python 3.11+ with tomllib is required for TOML validation"
    }
    finally {
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    }
}

function Assert-MarkdownLinks {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $text = Read-Utf8Text $Path
    $text = [regex]::Replace(
        $text,
        '(?ms)^(?<fence>`{3,}|~{3,})[^\r\n]*\r?\n.*?^\k<fence>[ \t]*\r?$',
        ''
    )
    $pattern = '\]\(\s*(<[^>]+>|[^)\s]+)'
    foreach ($match in [regex]::Matches($text, $pattern)) {
        $target = $match.Groups[1].Value.Trim()
        if ($target.StartsWith("<") -and $target.EndsWith(">")) {
            $target = $target.Substring(1, $target.Length - 2)
        }
        if ($target -match '^(?i:https?:|mailto:|ftp:|//)') {
            continue
        }
        $fragmentIndex = $target.IndexOf("#", [System.StringComparison]::Ordinal)
        if ($fragmentIndex -ge 0) {
            $target = $target.Substring(0, $fragmentIndex)
        }
        $queryIndex = $target.IndexOf("?", [System.StringComparison]::Ordinal)
        if ($queryIndex -ge 0) {
            $target = $target.Substring(0, $queryIndex)
        }
        if ([string]::IsNullOrWhiteSpace($target)) {
            continue
        }
        try {
            $decoded = [System.Uri]::UnescapeDataString($target)
            $candidate = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $Path) $decoded))
        }
        catch {
            throw "Validation: invalid Markdown link in $Path"
        }
        $rootPrefix = $Root.TrimEnd([char[]]"/\") + [System.IO.Path]::DirectorySeparatorChar
        if (-not $candidate.Equals($Root, [System.StringComparison]::OrdinalIgnoreCase) -and
            -not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Validation: Markdown link escapes the repository: $Path"
        }
        if (-not (Test-Path -LiteralPath $candidate)) {
            throw "Validation: Markdown link target is missing: $target in $Path"
        }
    }
}

function Assert-Svg {
    param([Parameter(Mandatory = $true)][string]$Path)
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = $null
    try {
        $reader = [System.Xml.XmlReader]::Create($Path, $settings)
        $document = New-Object System.Xml.XmlDocument
        $document.XmlResolver = $null
        $document.Load($reader)
        if ($null -eq $document.DocumentElement -or $document.DocumentElement.LocalName -ne "svg") {
            throw "Validation: SVG root element is missing: $Path"
        }
        $svgText = Read-Utf8Text $Path
        if ($svgText -match '(?i)(?:href|src|xlink:href)\s*=\s*["'']https?://|url\(\s*https?://') {
            throw "Validation: SVG contains a remote reference: $Path"
        }
    }
    catch {
        if ($_.Exception.Message -like "Validation:*") {
            throw
        }
        throw "Validation: invalid SVG: $Path"
    }
    finally {
        if ($null -ne $reader) {
            $reader.Close()
        }
    }
}

function Assert-PowerShellSyntax {
    param([Parameter(Mandatory = $true)][string]$Path)
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null
    if ($null -ne $errors -and $errors.Count -ne 0) {
        throw "Validation: PowerShell syntax validation failed: $Path"
    }
}

function Assert-RepositoryTextSafety {
    param([Parameter(Mandatory = $true)][string]$Root)

    $credentialPatterns = @(
        'AKIA[0-9A-Z]{16}',
        '-----BEGIN [A-Z0-9 ]+ PRIVATE KEY-----',
        'gh[pousr]_[A-Za-z0-9_]{20,}',
        'sk-[A-Za-z0-9]{20,}',
        'xox[baprs]-[A-Za-z0-9-]{20,}',
        '(?i)(?:api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token|password)\s*[:=]\s*[''\"][A-Za-z0-9_./+=-]{16,}[''\"]'
    )
    $gitPattern = [System.IO.Path]::DirectorySeparatorChar + ".git" + [System.IO.Path]::DirectorySeparatorChar
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -File -Force -Recurse)) {
        if ($file.FullName.IndexOf($gitPattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            continue
        }
        if ($file.FullName -match '(?i)(?:\\|/)__pycache__(?:\\|/|$)' -or
            $file.Extension -eq ".pyc" -or $file.Extension -eq ".pyo" -or
            $file.Name -eq ".DS_Store") {
            continue
        }
        try {
            $text = Read-Utf8Text $file.FullName
        }
        catch {
            continue
        }
        foreach ($line in ($text -split "`r?`n")) {
            if ($line.EndsWith(" ") -or $line.EndsWith("`t")) {
                throw "Validation: trailing whitespace: $($file.FullName)"
            }
        }
        if ($text.Length -gt 0 -and -not ($text.EndsWith("`n") -or $text.EndsWith("`r"))) {
            throw "Validation: text file has no final newline: $($file.FullName)"
        }
        foreach ($pattern in $credentialPatterns) {
            if ($text -match $pattern) {
                throw "Validation: possible sensitive data in: $($file.FullName)"
            }
        }
    }
}

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$requiredFiles = @(
    ".agents/skills/sol-control/SKILL.md",
    ".agents/skills/sol-control/agents/openai.yaml",
    ".agents/skills/sol-control/references/orchestration.md",
    ".agents/skills/sol-control/references/runtime-notes.md",
    ".agents/skills/sol-luna/SKILL.md",
    ".agents/skills/sol-luna/agents/openai.yaml",
    ".codex/agents/sol-controller.toml",
    ".codex/agents/luna-max-worker.toml",
    ".codex/agents/terra-high-worker.toml",
    "scripts/install.sh",
    "scripts/validate.sh",
    "scripts/test.sh",
    "scripts/uninstall.sh",
    "scripts/install.ps1",
    "scripts/validate.ps1",
    "scripts/uninstall.ps1",
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
    "docs/assets/readme/hero-zh.svg",
    "docs/assets/readme/hero-en.svg",
    "docs/assets/readme/control-plane-zh.svg",
    "docs/assets/readme/control-plane-en.svg",
    "tests/windows-lifecycle.ps1",
    "tests/test_release_engineering.py",
    ".github/workflows/windows-validation.yml",
    ".github/workflows/posix-validation.yml",
    "NOTICE",
    "LICENSE"
)

foreach ($relative in $requiredFiles) {
    Assert-File (Join-Path $repoRoot $relative)
}

$contributingText = Read-Utf8Text (Join-Path $repoRoot "CONTRIBUTING.md")
Assert-Regex $contributingText 'bash scripts/test\.sh' "CONTRIBUTING.md is missing the test command"
Assert-Regex $contributingText 'Apache License 2\.0' "CONTRIBUTING.md is missing the contribution license"

$codeOfConductText = Read-Utf8Text (Join-Path $repoRoot "CODE_OF_CONDUCT.md")
Assert-Regex $codeOfConductText 'Contributor Covenant' "CODE_OF_CONDUCT.md is missing its upstream attribution"

$securityText = Read-Utf8Text (Join-Path $repoRoot "SECURITY.md")
Assert-Regex $securityText '/security/advisories/new' "SECURITY.md is missing private vulnerability reporting"
Assert-Regex $securityText 'Do not open a public issue' "SECURITY.md is missing its public disclosure warning"

$readmeText = Read-Utf8Text (Join-Path $repoRoot "README.md")
$englishReadmeText = Read-Utf8Text (Join-Path $repoRoot "README.en.md")
Assert-Regex $readmeText 'SUPPORT\.md' "README.md is missing the support entry"
Assert-Regex $englishReadmeText 'SUPPORT\.md' "README.en.md is missing the support entry"

$issueConfigText = Read-Utf8Text (Join-Path $repoRoot ".github/ISSUE_TEMPLATE/config.yml")
Assert-Regex $issueConfigText '(?m)^blank_issues_enabled:\s*false\s*$' "issue template config permits blank issues"
Assert-Regex $issueConfigText 'Security vulnerability' "issue template config is missing private security routing"

$pullRequestTemplateText = Read-Utf8Text (Join-Path $repoRoot ".github/pull_request_template.md")
Assert-Regex $pullRequestTemplateText 'Validation and evidence' "pull request template is missing evidence guidance"

$skillRoot = Join-Path $repoRoot ".agents/skills/sol-control"
Assert-PlainTree $skillRoot
$skillText = Read-Utf8Text (Join-Path $skillRoot "SKILL.md")
$skillLines = @($skillText -split "`r?`n")
if ($skillLines.Count -lt 3 -or $skillLines[0] -ne "---") {
    throw "Validation: SKILL.md has no YAML frontmatter opener"
}
$closingIndex = -1
for ($index = 1; $index -lt $skillLines.Count; $index++) {
    if ($skillLines[$index] -eq "---") {
        $closingIndex = $index
        break
    }
}
if ($closingIndex -lt 0) {
    throw "Validation: SKILL.md has no YAML frontmatter closer"
}
$frontmatter = ($skillLines[1..($closingIndex - 1)] -join "`n")
Assert-Regex $frontmatter '(?m)^name:\s*sol-control\s*$' "SKILL.md has the wrong name"
Assert-Regex $frontmatter '(?m)^description:\s*Use when\b' "SKILL.md has no usable description"
Assert-Regex $skillText '\$sol-control' 'SKILL.md does not expose $sol-control'

$openaiText = Read-Utf8Text (Join-Path $skillRoot "agents/openai.yaml")
foreach ($marker in @("interface:", "display_name:", "short_description:", "default_prompt:")) {
    if ($openaiText.IndexOf($marker, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Validation: openai.yaml is missing $marker"
    }
}
Assert-Regex $openaiText '\$sol-control' 'openai.yaml does not expose $sol-control'
Assert-Regex $openaiText '(?m)^\s*allow_implicit_invocation:\s*false\s*$' "openai.yaml permits implicit invocation"

$compatSkillRoot = Join-Path $repoRoot ".agents/skills/sol-luna"
Assert-PlainTree $compatSkillRoot
$compatSkillText = Read-Utf8Text (Join-Path $compatSkillRoot "SKILL.md")
if (@($compatSkillText -split "`r?`n").Count -gt 45) {
    throw "Validation: compatibility SKILL.md is not thin"
}
foreach ($pattern in @('(?m)^name:\s*sol-luna\s*$', '\$sol-luna', '\$sol-control', 'v0\.5\.0')) {
    Assert-Regex $compatSkillText $pattern "compatibility SKILL.md is incomplete"
}
$compatOpenaiText = Read-Utf8Text (Join-Path $compatSkillRoot "agents/openai.yaml")
foreach ($pattern in @('\$sol-luna', '\$sol-control', '(?m)^\s*allow_implicit_invocation:\s*false\s*$')) {
    Assert-Regex $compatOpenaiText $pattern "compatibility openai.yaml is incomplete"
}

$solPath = Join-Path $repoRoot ".codex/agents/sol-controller.toml"
$lunaPath = Join-Path $repoRoot ".codex/agents/luna-max-worker.toml"
$terraPath = Join-Path $repoRoot ".codex/agents/terra-high-worker.toml"
Assert-TomlAgents $solPath $lunaPath $terraPath

foreach ($markdown in @(Get-ChildItem -LiteralPath $repoRoot -Filter "*.md" -File -Force -Recurse)) {
    if ($markdown.FullName.IndexOf(([System.IO.Path]::DirectorySeparatorChar + ".git" + [System.IO.Path]::DirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        continue
    }
    Assert-MarkdownLinks $repoRoot $markdown.FullName
}

Assert-Svg (Join-Path $repoRoot "docs/assets/readme/hero-zh.svg")
Assert-Svg (Join-Path $repoRoot "docs/assets/readme/hero-en.svg")
Assert-Svg (Join-Path $repoRoot "docs/assets/readme/control-plane-zh.svg")
Assert-Svg (Join-Path $repoRoot "docs/assets/readme/control-plane-en.svg")

$workflowPath = Join-Path $repoRoot ".github/workflows/windows-validation.yml"
$workflowText = Read-Utf8Text $workflowPath
foreach ($marker in @(
    "windows-latest",
    "windows-2022",
    "powershell",
    "pwsh",
    "tests/windows-lifecycle.ps1",
    "unittest discover"
)) {
    if ($workflowText.IndexOf($marker, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Validation: Windows workflow is missing $marker"
    }
}

$posixWorkflowPath = Join-Path $repoRoot ".github/workflows/posix-validation.yml"
$posixWorkflowText = Read-Utf8Text $posixWorkflowPath
foreach ($marker in @(
    "macos-latest",
    "ubuntu-latest",
    "3.11",
    "3.13",
    "scripts/test.sh",
    "install.sh --check"
)) {
    if ($posixWorkflowText.IndexOf($marker, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Validation: POSIX workflow is missing $marker"
    }
}

foreach ($path in @(
    (Join-Path $repoRoot "scripts/install.ps1"),
    (Join-Path $repoRoot "scripts/validate.ps1"),
    (Join-Path $repoRoot "scripts/uninstall.ps1"),
    (Join-Path $repoRoot "tests/windows-lifecycle.ps1")
)) {
    Assert-PowerShellSyntax $path
}

$forbiddenSkillTerms = @("IPZOR", "Buzz", "DeepSeek", "OpenPencil")
foreach ($path in @(Get-ChildItem -LiteralPath $skillRoot -File -Force -Recurse)) {
    $text = Read-Utf8Text $path.FullName
    foreach ($term in $forbiddenSkillTerms) {
        if ($text.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw "Validation: forbidden residue in skill source: $term"
        }
    }
}
foreach ($path in @(Get-ChildItem -LiteralPath $compatSkillRoot -File -Force -Recurse)) {
    $text = Read-Utf8Text $path.FullName
    foreach ($term in $forbiddenSkillTerms) {
        if ($text.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw "Validation: forbidden residue in compatibility skill source: $term"
        }
    }
}

Assert-RepositoryTextSafety $repoRoot
Write-Output "Validation: PASS"
