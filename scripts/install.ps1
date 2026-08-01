#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
# The transaction catch block below performs rollback before rethrowing.

function Test-PathExists {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Test-Path -LiteralPath $Path) -or (Test-Path -LiteralPath $Path -PathType Leaf)
}

function Test-ReparsePoint {
    param([Parameter(Mandatory = $true)]$Item)
    return (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-PathExists $Path) {
        $item = Get-Item -LiteralPath $Path -Force
        if (-not $item.PSIsContainer -or (Test-ReparsePoint $item)) {
            throw "unsafe install directory"
        }
    }
    else {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Assert-PlainTree {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-PathExists $Path)) {
        return
    }
    $rootItem = Get-Item -LiteralPath $Path -Force
    if (Test-ReparsePoint $rootItem) {
        throw "symbolic links and reparse points are not supported in owned targets"
    }
    if ($rootItem.PSIsContainer) {
        Get-ChildItem -LiteralPath $Path -Force -Recurse | ForEach-Object {
            if (Test-ReparsePoint $_) {
                throw "symbolic links and reparse points are not supported in owned targets"
            }
        }
    }
}

function Assert-Target {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][ValidateSet("Directory", "File")][string]$Kind
    )
    if (-not (Test-PathExists $Path)) {
        return
    }
    $item = Get-Item -LiteralPath $Path -Force
    if (Test-ReparsePoint $item) {
        throw "unsafe existing target"
    }
    if ($Kind -eq "Directory" -and -not $item.PSIsContainer) {
        throw "existing directory target has the wrong type"
    }
    if ($Kind -eq "File" -and $item.PSIsContainer) {
        throw "existing file target has the wrong type"
    }
    Assert-PlainTree $Path
}

function Get-FileDigest {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-BytesDigest {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-TreeDigest {
    param([Parameter(Mandatory = $true)][string]$Path)
    $entries = New-Object System.Collections.Generic.List[string]
    $items = Get-ChildItem -LiteralPath $Path -Force -Recurse | Sort-Object -Property FullName
    foreach ($item in $items) {
        $relative = $item.FullName.Substring($Path.Length).TrimStart([char[]]("/\"))
        if ($item.PSIsContainer) {
            $entries.Add("D|$relative")
        }
        else {
            $entries.Add("F|$relative|$(Get-FileDigest $item.FullName)")
        }
    }
    $text = if ($entries.Count -gt 0) { ($entries -join [Environment]::NewLine) + [Environment]::NewLine } else { "" }
    return Get-BytesDigest ([System.Text.Encoding]::UTF8.GetBytes($text))
}

function Copy-Exact {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    if ((Get-Item -LiteralPath $Source -Force).PSIsContainer) {
        Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
    }
    else {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
}

function Remove-Exact {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-PathExists $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Write-Utf8Text {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-StateMap {
    param([Parameter(Mandatory = $true)][string]$Path)
    $map = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -notmatch "^(?<key>[A-Za-z_]+)=(?<value>.*)$") {
            throw "invalid install state"
        }
        $map[$Matches.key] = $Matches.value
    }
    return $map
}

function Assert-Source {
    param([Parameter(Mandatory = $true)][string]$Root)

    $required = @(
        ".agents/skills/orchestrate-sol-luna/SKILL.md",
        ".agents/skills/orchestrate-sol-luna/agents/openai.yaml",
        ".agents/skills/orchestrate-sol-luna/references/routing-protocol.md",
        ".codex/agents/sol-planner.toml",
        ".codex/agents/luna-max-worker.toml",
        "scripts/install.sh",
        "scripts/validate.sh",
        "scripts/uninstall.sh",
        "scripts/install.ps1",
        "README.md",
        "NOTICE",
        "LICENSE"
    )
    foreach ($relative in $required) {
        $path = Join-Path $Root $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "source validation failed"
        }
    }

    $skill = Get-Content -LiteralPath (Join-Path $Root ".agents/skills/orchestrate-sol-luna/SKILL.md") -Raw
    if ($skill -notmatch "(?m)^---\r?\n" -or
        $skill -notmatch "(?m)^name:\s*orchestrate-sol-luna\s*$" -or
        $skill -notmatch "(?m)^description:\s*Use when\b") {
        throw "source validation failed"
    }

    $openai = Get-Content -LiteralPath (Join-Path $Root ".agents/skills/orchestrate-sol-luna/agents/openai.yaml") -Raw
    foreach ($marker in @("interface:", "display_name:", "short_description:", "default_prompt:")) {
        if ($openai.IndexOf($marker, [System.StringComparison]::Ordinal) -lt 0) {
            throw "source validation failed"
        }
    }

    $sol = Get-Content -LiteralPath (Join-Path $Root ".codex/agents/sol-planner.toml") -Raw
    $luna = Get-Content -LiteralPath (Join-Path $Root ".codex/agents/luna-max-worker.toml") -Raw
    foreach ($pair in @(
        @($sol, '(?m)^\s*name\s*=\s*"sol-planner"\s*$'),
        @($sol, '(?m)^\s*model\s*=\s*"gpt-5\.6-sol"\s*$'),
        @($sol, '(?m)^\s*model_reasoning_effort\s*=\s*"high"\s*$'),
        @($sol, '(?m)^\s*sandbox_mode\s*=\s*"read-only"\s*$'),
        @($luna, '(?m)^\s*name\s*=\s*"luna-max-worker"\s*$'),
        @($luna, '(?m)^\s*model\s*=\s*"gpt-5\.6-luna"\s*$'),
        @($luna, '(?m)^\s*model_reasoning_effort\s*=\s*"max"\s*$'),
        @($luna, '(?m)^\s*sandbox_mode\s*=\s*"workspace-write"\s*$'),
        @($luna, '(?is)do not (spawn|create).*subagent')
    )) {
        if ($pair[0] -notmatch $pair[1]) {
            throw "source validation failed"
        }
    }

    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if ($null -ne $bash) {
        & $bash.Source (Join-Path $Root "scripts/validate.sh") *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "source validation failed"
        }
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Assert-Source $repoRoot

$rawBase = $env:ORCHESTRATE_HOME
if ([string]::IsNullOrWhiteSpace($rawBase)) {
    $rawBase = [Environment]::GetFolderPath("UserProfile")
}
$baseDir = [System.IO.Path]::GetFullPath($rawBase)
if ($baseDir -eq [System.IO.Path]::GetPathRoot($baseDir)) {
    throw "refusing the filesystem root as ORCHESTRATE_HOME"
}
Ensure-Directory $baseDir
$baseDir = (Get-Item -LiteralPath $baseDir -Force).FullName

$skillSource = Join-Path $repoRoot ".agents/skills/orchestrate-sol-luna"
$solSource = Join-Path $repoRoot ".codex/agents/sol-planner.toml"
$lunaSource = Join-Path $repoRoot ".codex/agents/luna-max-worker.toml"

$skillTarget = Join-Path $baseDir ".agents/skills/orchestrate-sol-luna"
$codexDir = Join-Path $baseDir ".codex"
$agentsDir = Join-Path $codexDir "agents"
$solTarget = Join-Path $agentsDir "sol-planner.toml"
$lunaTarget = Join-Path $agentsDir "luna-max-worker.toml"
$configTarget = Join-Path $codexDir "config.toml"
$stateRoot = Join-Path $codexDir "orchestrate-sol-luna"
$stateFile = Join-Path $stateRoot "install-state"
$backupRoot = Join-Path $stateRoot "backups"

Ensure-Directory (Join-Path $baseDir ".agents")
Ensure-Directory (Join-Path $baseDir ".agents/skills")
Ensure-Directory $codexDir
Ensure-Directory $agentsDir
Ensure-Directory $stateRoot
Ensure-Directory $backupRoot
Assert-Target $skillTarget "Directory"
Assert-Target $solTarget "File"
Assert-Target $lunaTarget "File"
if (Test-PathExists $configTarget) {
    Assert-Target $configTarget "File"
}

if (Test-PathExists $stateFile) {
    $oldState = Get-StateMap $stateFile
    if ($oldState.skill_sha256 -ne (Get-TreeDigest $skillTarget) -or
        $oldState.sol_sha256 -ne (Get-FileDigest $solTarget) -or
        $oldState.luna_sha256 -ne (Get-FileDigest $lunaTarget)) {
        throw "existing installed copies do not match install state"
    }
}

$backupId = "{0}-{1}" -f (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ"), $PID
$backupDir = Join-Path $backupRoot $backupId
while (Test-PathExists $backupDir) {
    $backupId = "{0}-{1}-{2}" -f (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ"), $PID, (Get-Random)
    $backupDir = Join-Path $backupRoot $backupId
}
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

$manifest = New-Object System.Collections.Generic.List[string]
$manifest.Add("version=1")
foreach ($entry in @(
    @("skill", $skillTarget, (Join-Path $backupDir "skill")),
    @("sol", $solTarget, (Join-Path $backupDir "sol-planner.toml")),
    @("luna", $lunaTarget, (Join-Path $backupDir "luna-max-worker.toml")),
    @("config", $configTarget, (Join-Path $backupDir "config.toml"))
)) {
    $label = $entry[0]
    $source = $entry[1]
    $destination = $entry[2]
    $presence = "absent"
    $digest = ""
    if (Test-PathExists $source) {
        $presence = "present"
        $digest = if ((Get-Item -LiteralPath $source -Force).PSIsContainer) { Get-TreeDigest $source } else { Get-FileDigest $source }
        Copy-Exact $source $destination
    }
    $manifest.Add("${label}_presence=$presence")
    $manifest.Add("${label}_sha256=$digest")
}
Write-Utf8Text (Join-Path $backupDir "manifest") (($manifest -join [Environment]::NewLine) + [Environment]::NewLine)

$transactionDir = Join-Path $stateRoot (".transaction-" + [Guid]::NewGuid().ToString("N"))
$stageDir = Join-Path $transactionDir "stage"
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
Copy-Exact $skillSource (Join-Path $stageDir "skill")
Copy-Exact $solSource (Join-Path $stageDir "sol-planner.toml")
Copy-Exact $lunaSource (Join-Path $stageDir "luna-max-worker.toml")

$stateHad = $false
$stateNew = $false
$skillHad = $false
$skillNew = $false
$solHad = $false
$solNew = $false
$lunaHad = $false
$lunaNew = $false

try {
    if (Test-PathExists $stateFile) {
        Move-Item -LiteralPath $stateFile -Destination (Join-Path $transactionDir "old-state")
        $stateHad = $true
    }

    if (Test-PathExists $skillTarget) {
        Move-Item -LiteralPath $skillTarget -Destination (Join-Path $transactionDir "old-skill")
        $skillHad = $true
    }
    Move-Item -LiteralPath (Join-Path $stageDir "skill") -Destination $skillTarget
    $skillNew = $true

    if (Test-PathExists $solTarget) {
        Move-Item -LiteralPath $solTarget -Destination (Join-Path $transactionDir "old-sol")
        $solHad = $true
    }
    Move-Item -LiteralPath (Join-Path $stageDir "sol-planner.toml") -Destination $solTarget
    $solNew = $true

    if (Test-PathExists $lunaTarget) {
        Move-Item -LiteralPath $lunaTarget -Destination (Join-Path $transactionDir "old-luna")
        $lunaHad = $true
    }
    Move-Item -LiteralPath (Join-Path $stageDir "luna-max-worker.toml") -Destination $lunaTarget
    $lunaNew = $true

    $newState = @(
        "version=1",
        "backup_id=$backupId",
        "skill_sha256=$(Get-TreeDigest $skillTarget)",
        "sol_sha256=$(Get-FileDigest $solTarget)",
        "luna_sha256=$(Get-FileDigest $lunaTarget)"
    ) -join [Environment]::NewLine
    $stateTemp = Join-Path $stateRoot (".install-state-" + [Guid]::NewGuid().ToString("N"))
    Write-Utf8Text $stateTemp ($newState + [Environment]::NewLine)
    Move-Item -LiteralPath $stateTemp -Destination $stateFile
    $stateNew = $true

    Remove-Exact $transactionDir
}
catch {
    if ($stateNew) { Remove-Exact $stateFile }
    if ($stateHad -and (Test-PathExists (Join-Path $transactionDir "old-state"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-state") -Destination $stateFile
    }
    if ($lunaNew) { Remove-Exact $lunaTarget }
    if ($lunaHad -and (Test-PathExists (Join-Path $transactionDir "old-luna"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-luna") -Destination $lunaTarget
    }
    if ($solNew) { Remove-Exact $solTarget }
    if ($solHad -and (Test-PathExists (Join-Path $transactionDir "old-sol"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-sol") -Destination $solTarget
    }
    if ($skillNew) { Remove-Exact $skillTarget }
    if ($skillHad -and (Test-PathExists (Join-Path $transactionDir "old-skill"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-skill") -Destination $skillTarget
    }
    if (Test-PathExists $transactionDir) { Remove-Exact $transactionDir }
    throw
}

Write-Output "Install path: $skillTarget"
Write-Output "Install path: $solTarget"
Write-Output "Install path: $lunaTarget"
Write-Output "Backup path: $backupDir"
