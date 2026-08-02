#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
# Transaction rollback restores every moved target before the error is rethrown.
$script:CreatedDirectories = New-Object System.Collections.Generic.List[string]

function Test-PathExists {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Test-Path -LiteralPath $Path)
}

function Test-ReparsePoint {
    param([Parameter(Mandatory = $true)]$Item)
    return (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Assert-PathChain {
    param([Parameter(Mandatory = $true)][string]$Path)
    $cursor = [System.IO.Path]::GetFullPath($Path)
    while ($true) {
        if (Test-PathExists $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (Test-ReparsePoint $item) {
                throw "unsafe path contains a reparse point"
            }
            if (-not $item.PSIsContainer -and $cursor -ne $Path) {
                throw "unsafe path ancestor is not a directory"
            }
        }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $cursor) {
            break
        }
        $cursor = $parent
    }
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (Test-PathExists $Path) {
        $item = Get-Item -LiteralPath $Path -Force
        if (-not $item.PSIsContainer -or (Test-ReparsePoint $item)) {
            throw "unsafe install directory"
        }
    }
    else {
        Assert-PathChain $fullPath
        $parent = Split-Path -Parent $fullPath
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $fullPath) {
            throw "cannot create an install directory"
        }
        Ensure-Directory $parent
        [System.IO.Directory]::CreateDirectory($fullPath) | Out-Null
        $script:CreatedDirectories.Add($fullPath)
    }
}

function Assert-PlainTree {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-PathExists $Path)) {
        return
    }
    $rootItem = Get-Item -LiteralPath $Path -Force
    if (Test-ReparsePoint $rootItem) {
        throw "symbolic links and reparse points are not supported in owned paths"
    }
    if ($rootItem.PSIsContainer) {
        Get-ChildItem -LiteralPath $Path -Force -Recurse | ForEach-Object {
            if (Test-ReparsePoint $_) {
                throw "symbolic links and reparse points are not supported in owned trees"
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
    Assert-PlainTree $Path
    $entries = New-Object System.Collections.Generic.List[string]
    $items = @(Get-ChildItem -LiteralPath $Path -Force -Recurse | Sort-Object -Property FullName)
    foreach ($item in $items) {
        $relative = $item.FullName.Substring($Path.Length).TrimStart([char[]]"/\").Replace("\", "/")
        if ($item.PSIsContainer) {
            $entries.Add("D`t$relative`n")
        }
        else {
            $entries.Add("F`t$relative`t$(Get-FileDigest $item.FullName)`n")
        }
    }
    $text = if ($entries.Count -gt 0) { $entries -join "" } else { "" }
    return Get-BytesDigest ([System.Text.Encoding]::UTF8.GetBytes($text))
}

function Copy-Exact {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    Assert-PlainTree $Source
    $parent = Split-Path -Parent $Destination
    if (-not (Test-PathExists $parent)) {
        throw "copy destination parent is missing"
    }
    Assert-Target $parent "Directory"
    if ((Get-Item -LiteralPath $Source -Force).PSIsContainer) {
        Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
    }
    else {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
    Assert-PlainTree $Destination
}

function Remove-Exact {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-PathExists $Path) {
        Assert-PlainTree $Path
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Remove-EmptyCreatedDirectories {
    for ($index = $script:CreatedDirectories.Count - 1; $index -ge 0; $index--) {
        $path = $script:CreatedDirectories[$index]
        if (-not (Test-PathExists $path)) {
            continue
        }
        try {
            $item = Get-Item -LiteralPath $path -Force
            if ($item.PSIsContainer -and -not (Test-ReparsePoint $item)) {
                Remove-Item -LiteralPath $path -Force -ErrorAction Stop
            }
        }
        catch {
            # A non-empty or concurrently changed parent is left untouched.
        }
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
    foreach ($line in @(Get-Content -LiteralPath $Path)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($line -notmatch "^(?<key>[A-Za-z_][A-Za-z0-9_]*)=(?<value>.*)$") {
            throw "invalid install state"
        }
        if ($map.ContainsKey($Matches.key)) {
            throw "duplicate install state key"
        }
        $map[$Matches.key] = $Matches.value
    }
    return $map
}

function Get-StateValue {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Map,
        [Parameter(Mandatory = $true)][string]$Key
    )
    if (-not $Map.ContainsKey($Key)) {
        throw "install state is incomplete"
    }
    return [string]$Map[$Key]
}

function Assert-Hash {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ($Value -notmatch "^[0-9a-f]{64}$") {
        throw "invalid checksum"
    }
}

function Assert-BackupId {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ($Value -notmatch "^[A-Za-z0-9._-]+$" -or $Value -eq "." -or $Value -eq "..") {
        throw "unsafe backup identifier"
    }
}

function Assert-Source {
    param([Parameter(Mandatory = $true)][string]$Root)

    $required = @(
        ".agents/skills/sol-luna/SKILL.md",
        ".agents/skills/sol-luna/agents/openai.yaml",
        ".codex/agents/sol-controller.toml",
        ".codex/agents/luna-max-worker.toml",
        "scripts/install.sh",
        "scripts/validate.sh",
        "scripts/uninstall.sh",
        "scripts/install.ps1",
        "scripts/validate.ps1",
        "scripts/uninstall.ps1",
        "README.md",
        "README.en.md",
        "docs/assets/sol-luna-hero.svg",
        "docs/assets/sol-luna-architecture.svg",
        "tests/windows-lifecycle.ps1",
        "NOTICE",
        "LICENSE"
    )
    foreach ($relative in $required) {
        $path = Join-Path $Root $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "source validation failed"
        }
        $fileItem = Get-Item -LiteralPath $path -Force
        if (Test-ReparsePoint $fileItem) {
            throw "source validation failed"
        }
    }

    $skillRoot = Join-Path $Root ".agents/skills/sol-luna"
    Assert-PlainTree $skillRoot
    $runtimeDirect = Join-Path $skillRoot "runtime-notes.md"
    $runtimeReference = Join-Path $skillRoot "references/runtime-notes.md"
    if (-not (Test-Path -LiteralPath $runtimeDirect -PathType Leaf) -and
        -not (Test-Path -LiteralPath $runtimeReference -PathType Leaf)) {
        throw "source validation failed"
    }

    $skill = Get-Content -LiteralPath (Join-Path $skillRoot "SKILL.md") -Raw
    if ($skill -notmatch "(?m)^---\r?$" -or
        $skill -notmatch "(?m)^name:\s*sol-luna\s*$" -or
        $skill -notmatch "(?m)^description:\s*Use when\b" -or
        $skill -notmatch '\$sol-luna') {
        throw "source validation failed"
    }

    $openai = Get-Content -LiteralPath (Join-Path $skillRoot "agents/openai.yaml") -Raw
    foreach ($marker in @("interface:", "display_name:", "short_description:", "default_prompt:")) {
        if ($openai.IndexOf($marker, [System.StringComparison]::Ordinal) -lt 0) {
            throw "source validation failed"
        }
    }

    $sol = Get-Content -LiteralPath (Join-Path $Root ".codex/agents/sol-controller.toml") -Raw
    $luna = Get-Content -LiteralPath (Join-Path $Root ".codex/agents/luna-max-worker.toml") -Raw
    foreach ($pair in @(
        @($sol, '(?m)^\s*name\s*=\s*"sol-controller"\s*$'),
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

    $validator = Join-Path $Root "scripts/validate.ps1"
    try {
        & $validator *> $null
    }
    catch {
        throw "source validation failed: $($_.Exception.Message)"
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Assert-Source $repoRoot

$rawBase = $env:ORCHESTRATE_HOME
if ([string]::IsNullOrWhiteSpace($rawBase)) {
    $rawBase = [Environment]::GetFolderPath("UserProfile")
}
if ([string]::IsNullOrWhiteSpace($rawBase) -or -not [System.IO.Path]::IsPathRooted($rawBase)) {
    throw "ORCHESTRATE_HOME must be an absolute path"
}
$baseDir = [System.IO.Path]::GetFullPath($rawBase)
if ($baseDir -eq [System.IO.Path]::GetPathRoot($baseDir)) {
    throw "refusing the filesystem root as ORCHESTRATE_HOME"
}
Assert-PathChain $baseDir

$skillSource = Join-Path $repoRoot ".agents/skills/sol-luna"
$solSource = Join-Path $repoRoot ".codex/agents/sol-controller.toml"
$lunaSource = Join-Path $repoRoot ".codex/agents/luna-max-worker.toml"

$newSkillTarget = Join-Path $baseDir ".agents/skills/sol-luna"
$newSolTarget = Join-Path $baseDir ".codex/agents/sol-controller.toml"
$lunaTarget = Join-Path $baseDir ".codex/agents/luna-max-worker.toml"
$legacySkillTarget = Join-Path $baseDir ".agents/skills/orchestrate-sol-luna"
$legacySolTarget = Join-Path $baseDir ".codex/agents/sol-planner.toml"
$codexDir = Join-Path $baseDir ".codex"
$agentsDir = Join-Path $codexDir "agents"
$configTarget = Join-Path $codexDir "config.toml"
$stateRoot = Join-Path $codexDir "sol-luna"
$stateFile = Join-Path $stateRoot "install-state"
$backupRoot = Join-Path $stateRoot "backups"
$legacyStateRoot = Join-Path $codexDir "orchestrate-sol-luna"
$legacyStateFile = Join-Path $legacyStateRoot "install-state"

foreach ($directory in @(
    (Join-Path $baseDir ".agents"),
    (Join-Path $baseDir ".agents/skills"),
    $codexDir,
    $agentsDir,
    $stateRoot,
    $backupRoot,
    $legacyStateRoot
)) {
    if (Test-PathExists $directory) {
        $item = Get-Item -LiteralPath $directory -Force
        if (-not $item.PSIsContainer -or (Test-ReparsePoint $item)) {
            throw "unsafe install parent"
        }
    }
}

Assert-Target $newSkillTarget "Directory"
Assert-Target $newSolTarget "File"
Assert-Target $lunaTarget "File"
Assert-Target $legacySkillTarget "Directory"
Assert-Target $legacySolTarget "File"
if (Test-PathExists $configTarget) { Assert-Target $configTarget "File" }
if (Test-PathExists $stateFile) { Assert-Target $stateFile "File" }
if (Test-PathExists $legacyStateFile) { Assert-Target $legacyStateFile "File" }

$v2StatePresent = $false
if (Test-PathExists $stateFile) {
    $v2State = Get-StateMap $stateFile
    if ((Get-StateValue $v2State "version") -ne "2") {
        throw "existing v0.2 state has an unsupported version"
    }
    $v2BackupId = Get-StateValue $v2State "backup_id"
    Assert-BackupId $v2BackupId
    $v2SkillDigest = Get-StateValue $v2State "skill_sha256"
    $v2SolDigest = Get-StateValue $v2State "sol_sha256"
    $v2LunaDigest = Get-StateValue $v2State "luna_sha256"
    Assert-Hash $v2SkillDigest
    Assert-Hash $v2SolDigest
    Assert-Hash $v2LunaDigest
    if (-not (Test-Path -LiteralPath $newSkillTarget -PathType Container) -or
        -not (Test-Path -LiteralPath $newSolTarget -PathType Leaf) -or
        -not (Test-Path -LiteralPath $lunaTarget -PathType Leaf)) {
        throw "existing v0.2 targets are missing"
    }
    if ((Get-TreeDigest $newSkillTarget) -ne $v2SkillDigest -or
        (Get-FileDigest $newSolTarget) -ne $v2SolDigest -or
        (Get-FileDigest $lunaTarget) -ne $v2LunaDigest) {
        throw "existing v0.2 targets do not match install state"
    }
    $v2StatePresent = $true
}
elseif ((Test-PathExists $newSkillTarget) -or (Test-PathExists $newSolTarget)) {
    throw "existing v0.2 target has no ownership state"
}

$legacyStatePresent = $false
$legacySkillDigest = ""
$legacySolDigest = ""
$legacyLunaDigest = ""
if (Test-PathExists $legacyStateFile) {
    $legacyState = Get-StateMap $legacyStateFile
    if ((Get-StateValue $legacyState "version") -ne "1") {
        throw "existing v0.1 state has an unsupported version"
    }
    $legacySkillDigest = Get-StateValue $legacyState "skill_sha256"
    $legacySolDigest = Get-StateValue $legacyState "sol_sha256"
    $legacyLunaDigest = Get-StateValue $legacyState "luna_sha256"
    Assert-Hash $legacySkillDigest
    Assert-Hash $legacySolDigest
    Assert-Hash $legacyLunaDigest
    $legacyStatePresent = $true
}

$legacySkillRemove = $false
$legacySolRemove = $false
if ($legacyStatePresent) {
    if ((Test-PathExists $legacySkillTarget) -and ((Get-TreeDigest $legacySkillTarget) -eq $legacySkillDigest)) {
        $legacySkillRemove = $true
    }
    if ((Test-PathExists $legacySolTarget) -and ((Get-FileDigest $legacySolTarget) -eq $legacySolDigest)) {
        $legacySolRemove = $true
    }
}
if (-not $v2StatePresent -and (Test-PathExists $lunaTarget)) {
    if ($legacyStatePresent) {
        if ((Get-FileDigest $lunaTarget) -ne $legacyLunaDigest) {
            throw "shared Luna was modified; refusing migration"
        }
    }
    else {
        throw "existing shared Luna has no ownership state"
    }
}

$backupId = "{0}-{1}" -f (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ"), $PID
$backupDir = Join-Path $backupRoot $backupId
$transactionDir = ""
$manifestTemp = ""
$stateTemp = ""
$stateOld = $false
$stateNew = $false
$skillOld = $false
$skillNew = $false
$solOld = $false
$solNew = $false
$lunaOld = $false
$lunaNew = $false
$legacySkillOld = $false
$legacySolOld = $false

try {
    Ensure-Directory $baseDir
    $baseDir = (Get-Item -LiteralPath $baseDir -Force).FullName
    Assert-PathChain $baseDir
    if (Test-ReparsePoint (Get-Item -LiteralPath $baseDir -Force)) {
        throw "ORCHESTRATE_HOME must not be a reparse point"
    }
    Ensure-Directory (Join-Path $baseDir ".agents")
    Ensure-Directory (Join-Path $baseDir ".agents/skills")
    Ensure-Directory $codexDir
    Ensure-Directory $agentsDir
    Ensure-Directory $stateRoot
    Ensure-Directory $backupRoot

    while (Test-PathExists $backupDir) {
        $backupId = "{0}-{1}-{2}" -f (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ"), $PID, (Get-Random)
        $backupDir = Join-Path $backupRoot $backupId
    }
    Ensure-Directory $backupDir
    Ensure-Directory (Join-Path $backupDir "legacy")
    Ensure-Directory (Join-Path $backupDir "v020")

    $legacySkillPresence = "absent"
    $legacySkillBackupDigest = ""
    if (Test-PathExists $legacySkillTarget) {
        $legacySkillPresence = "present"
        $legacySkillBackupDigest = Get-TreeDigest $legacySkillTarget
        Copy-Exact $legacySkillTarget (Join-Path $backupDir "legacy/skill")
    }
    $legacySolPresence = "absent"
    $legacySolBackupDigest = ""
    if (Test-PathExists $legacySolTarget) {
        $legacySolPresence = "present"
        $legacySolBackupDigest = Get-FileDigest $legacySolTarget
        Copy-Exact $legacySolTarget (Join-Path $backupDir "legacy/sol-planner.toml")
    }
    $legacyLunaPresence = "absent"
    $legacyLunaBackupDigest = ""
    if (Test-PathExists $lunaTarget) {
        $legacyLunaPresence = "present"
        $legacyLunaBackupDigest = Get-FileDigest $lunaTarget
        Copy-Exact $lunaTarget (Join-Path $backupDir "legacy/luna-max-worker.toml")
    }

    $v020SkillPresence = "absent"
    $v020SkillBackupDigest = ""
    if (Test-PathExists $newSkillTarget) {
        $v020SkillPresence = "present"
        $v020SkillBackupDigest = Get-TreeDigest $newSkillTarget
        Copy-Exact $newSkillTarget (Join-Path $backupDir "v020/skill")
    }
    $v020SolPresence = "absent"
    $v020SolBackupDigest = ""
    if (Test-PathExists $newSolTarget) {
        $v020SolPresence = "present"
        $v020SolBackupDigest = Get-FileDigest $newSolTarget
        Copy-Exact $newSolTarget (Join-Path $backupDir "v020/sol-controller.toml")
    }
    $v020LunaPresence = $legacyLunaPresence
    $v020LunaBackupDigest = $legacyLunaBackupDigest
    if ($legacyLunaPresence -eq "present") {
        Copy-Exact $lunaTarget (Join-Path $backupDir "v020/luna-max-worker.toml")
    }

    $configPresence = "absent"
    $configDigest = ""
    if (Test-PathExists $configTarget) {
        $configPresence = "present"
        $configDigest = Get-FileDigest $configTarget
    }

    $manifest = New-Object System.Collections.Generic.List[string]
    $manifest.Add("version=2")
    $manifest.Add("legacy_skill_presence=$legacySkillPresence")
    $manifest.Add("legacy_skill_sha256=$legacySkillBackupDigest")
    $manifest.Add("legacy_sol_presence=$legacySolPresence")
    $manifest.Add("legacy_sol_sha256=$legacySolBackupDigest")
    $manifest.Add("legacy_luna_presence=$legacyLunaPresence")
    $manifest.Add("legacy_luna_sha256=$legacyLunaBackupDigest")
    $manifest.Add("v020_skill_presence=$v020SkillPresence")
    $manifest.Add("v020_skill_sha256=$v020SkillBackupDigest")
    $manifest.Add("v020_sol_presence=$v020SolPresence")
    $manifest.Add("v020_sol_sha256=$v020SolBackupDigest")
    $manifest.Add("v020_luna_presence=$v020LunaPresence")
    $manifest.Add("v020_luna_sha256=$v020LunaBackupDigest")
    $manifest.Add("config_presence=$configPresence")
    $manifest.Add("config_sha256=$configDigest")
    $manifestTemp = Join-Path $backupDir (".manifest-" + [Guid]::NewGuid().ToString("N"))
    Write-Utf8Text $manifestTemp (($manifest -join [Environment]::NewLine) + [Environment]::NewLine)
    Move-Item -LiteralPath $manifestTemp -Destination (Join-Path $backupDir "manifest")
    $manifestTemp = ""

    $transactionDir = Join-Path $stateRoot (".transaction-" + [Guid]::NewGuid().ToString("N"))
    Ensure-Directory $transactionDir
    Ensure-Directory (Join-Path $transactionDir "stage")
    Copy-Exact $skillSource (Join-Path $transactionDir "stage/v020-skill")
    Copy-Exact $solSource (Join-Path $transactionDir "stage/v020-sol-controller.toml")
    Copy-Exact $lunaSource (Join-Path $transactionDir "stage/v020-luna-max-worker.toml")

    if (Test-PathExists $stateFile) {
        Move-Item -LiteralPath $stateFile -Destination (Join-Path $transactionDir "old-state")
        $stateOld = $true
    }

    if (Test-PathExists $newSkillTarget) {
        Move-Item -LiteralPath $newSkillTarget -Destination (Join-Path $transactionDir "old-v020-skill")
        $skillOld = $true
    }
    Move-Item -LiteralPath (Join-Path $transactionDir "stage/v020-skill") -Destination $newSkillTarget
    $skillNew = $true

    if ($legacySkillRemove) {
        Move-Item -LiteralPath $legacySkillTarget -Destination (Join-Path $transactionDir "old-legacy-skill")
        $legacySkillOld = $true
    }

    if (Test-PathExists $newSolTarget) {
        Move-Item -LiteralPath $newSolTarget -Destination (Join-Path $transactionDir "old-v020-sol")
        $solOld = $true
    }
    Move-Item -LiteralPath (Join-Path $transactionDir "stage/v020-sol-controller.toml") -Destination $newSolTarget
    $solNew = $true

    if ($legacySolRemove) {
        Move-Item -LiteralPath $legacySolTarget -Destination (Join-Path $transactionDir "old-legacy-sol")
        $legacySolOld = $true
    }

    if (Test-PathExists $lunaTarget) {
        Move-Item -LiteralPath $lunaTarget -Destination (Join-Path $transactionDir "old-luna")
        $lunaOld = $true
    }
    Move-Item -LiteralPath (Join-Path $transactionDir "stage/v020-luna-max-worker.toml") -Destination $lunaTarget
    $lunaNew = $true

    if (-not [string]::IsNullOrWhiteSpace($env:ORCHESTRATE_HOME) -and
        $env:ORCHESTRATE_FAILPOINT -eq "after-replace") {
        throw "injected failure after replacement"
    }

    $newSkillDigest = Get-TreeDigest $newSkillTarget
    $newSolDigest = Get-FileDigest $newSolTarget
    $newLunaDigest = Get-FileDigest $lunaTarget
    Assert-Hash $newSkillDigest
    Assert-Hash $newSolDigest
    Assert-Hash $newLunaDigest

    $stateTemp = Join-Path $stateRoot (".install-state-" + [Guid]::NewGuid().ToString("N"))
    $stateText = @(
        "version=2",
        "backup_id=$backupId",
        "skill_sha256=$newSkillDigest",
        "sol_sha256=$newSolDigest",
        "luna_sha256=$newLunaDigest"
    ) -join [Environment]::NewLine
    Write-Utf8Text $stateTemp ($stateText + [Environment]::NewLine)
    Move-Item -LiteralPath $stateTemp -Destination $stateFile
    $stateTemp = ""
    $stateNew = $true

    if ($env:ORCHESTRATE_FAILPOINT -eq "after-state") {
        throw "injected failure after state"
    }

    Remove-Exact $transactionDir
    $transactionDir = ""
}
catch {
    if ($stateTemp -and (Test-PathExists $stateTemp)) { Remove-Exact $stateTemp }
    if ($manifestTemp -and (Test-PathExists $manifestTemp)) { Remove-Exact $manifestTemp }
    if ($stateNew) { Remove-Exact $stateFile }
    if ($stateOld -and (Test-PathExists (Join-Path $transactionDir "old-state"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-state") -Destination $stateFile
    }
    if ($lunaNew) { Remove-Exact $lunaTarget }
    if ($lunaOld -and (Test-PathExists (Join-Path $transactionDir "old-luna"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-luna") -Destination $lunaTarget
    }
    if ($solNew) { Remove-Exact $newSolTarget }
    if ($solOld -and (Test-PathExists (Join-Path $transactionDir "old-v020-sol"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-v020-sol") -Destination $newSolTarget
    }
    if ($skillNew) { Remove-Exact $newSkillTarget }
    if ($skillOld -and (Test-PathExists (Join-Path $transactionDir "old-v020-skill"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-v020-skill") -Destination $newSkillTarget
    }
    if ($legacySolOld -and (Test-PathExists (Join-Path $transactionDir "old-legacy-sol"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-legacy-sol") -Destination $legacySolTarget
    }
    if ($legacySkillOld -and (Test-PathExists (Join-Path $transactionDir "old-legacy-skill"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-legacy-skill") -Destination $legacySkillTarget
    }
    if ($transactionDir -and (Test-PathExists $transactionDir)) { Remove-Exact $transactionDir }
    if (Test-PathExists $backupDir) { Remove-Exact $backupDir }
    Remove-EmptyCreatedDirectories
    throw
}

Write-Output "Install path: $newSkillTarget"
Write-Output "Install path: $newSolTarget"
Write-Output "Install path: $lunaTarget"
Write-Output "Backup path: $backupDir"
