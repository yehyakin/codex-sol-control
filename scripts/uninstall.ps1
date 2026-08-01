#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$RestoreLatest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-PathExists {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [bool](Test-Path -LiteralPath $Path)
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

function Assert-PlainTree {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-PathExists $Path)) {
        throw "path is missing"
    }
    $rootItem = Get-Item -LiteralPath $Path -Force
    if (Test-ReparsePoint $rootItem) {
        throw "symbolic links and reparse points are not supported in owned paths"
    }
    if ($rootItem.PSIsContainer) {
        foreach ($item in @(Get-ChildItem -LiteralPath $Path -Force -Recurse)) {
            if (Test-ReparsePoint $item) {
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
    $sourceItem = Get-Item -LiteralPath $Source -Force
    if ($sourceItem.PSIsContainer) {
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

function Remove-EmptyDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-PathExists $Path)) {
        return
    }
    try {
        $item = Get-Item -LiteralPath $Path -Force
        if ($item.PSIsContainer -and -not (Test-ReparsePoint $item)) {
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
        }
    }
    catch {
        # Empty parent cleanup is best effort; owned files were already removed transactionally.
    }
}

function Get-StateMap {
    param([Parameter(Mandatory = $true)][string]$Path)
    $map = @{}
    foreach ($line in @(Get-Content -LiteralPath $Path)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($line -notmatch "^(?<key>[A-Za-z_]+)=(?<value>.*)$") {
            throw "invalid install state or backup manifest"
        }
        if ($map.ContainsKey($Matches.key)) {
            throw "duplicate install state or backup manifest key"
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
        throw "install state or backup manifest is incomplete"
    }
    return [string]$Map[$Key]
}

function Assert-Hash {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ($Value -notmatch "^[0-9a-f]{64}$") {
        throw "invalid SHA256 checksum"
    }
}

function Assert-BackupId {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ($Value -notmatch "^[A-Za-z0-9._-]+$" -or $Value -eq "." -or $Value -eq "..") {
        throw "install state contains an unsafe backup identifier"
    }
}

function Assert-BackupEntry {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Manifest,
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$PresenceKey,
        [Parameter(Mandatory = $true)][string]$ChecksumKey,
        [Parameter(Mandatory = $true)][string]$Artifact,
        [Parameter(Mandatory = $true)][ValidateSet("Directory", "File")][string]$Kind
    )
    $presence = Get-StateValue $Manifest $PresenceKey
    $checksum = Get-StateValue $Manifest $ChecksumKey
    if ($presence -ne "present" -and $presence -ne "absent") {
        throw "backup manifest has an invalid $Label presence value"
    }
    if ($presence -eq "present") {
        Assert-Hash $checksum
        Assert-Target $Artifact $Kind
        if ($Kind -eq "Directory") {
            $actual = Get-TreeDigest $Artifact
        }
        else {
            $actual = Get-FileDigest $Artifact
        }
        if ($actual -ne $checksum) {
            throw "recorded $Label backup was modified"
        }
    }
    else {
        if (-not [string]::IsNullOrEmpty($checksum)) {
            throw "absent $Label backup has a checksum"
        }
        if (Test-PathExists $Artifact) {
            throw "absent $Label backup has an unexpected artifact"
        }
    }
}

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
if (-not (Test-Path -LiteralPath $baseDir -PathType Container)) {
    throw "ORCHESTRATE_HOME is not an existing directory"
}
$baseDir = (Get-Item -LiteralPath $baseDir -Force).FullName
Assert-PathChain $baseDir

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

foreach ($directory in @(
    (Join-Path $baseDir ".agents"),
    (Join-Path $baseDir ".agents/skills"),
    $codexDir,
    $agentsDir,
    $stateRoot,
    $backupRoot
)) {
    if (Test-PathExists $directory) {
        Assert-Target $directory "Directory"
    }
}

if (-not (Test-Path -LiteralPath $stateRoot -PathType Container) -or
    -not (Test-Path -LiteralPath $stateFile -PathType Leaf)) {
    throw "no v0.2 installation state was found"
}
Assert-Target $stateRoot "Directory"
Assert-Target $stateFile "File"
if (-not (Test-Path -LiteralPath $backupRoot -PathType Container)) {
    throw "recorded backup root is unavailable"
}
Assert-Target $backupRoot "Directory"
if (Test-PathExists $configTarget) {
    Assert-Target $configTarget "File"
}
Assert-Target $newSkillTarget "Directory"
Assert-Target $newSolTarget "File"
Assert-Target $lunaTarget "File"
Assert-Target $legacySkillTarget "Directory"
Assert-Target $legacySolTarget "File"

$state = Get-StateMap $stateFile
if ((Get-StateValue $state "version") -ne "2") {
    throw "install state is not v0.2"
}
$backupId = Get-StateValue $state "backup_id"
Assert-BackupId $backupId
$backupDir = Join-Path $backupRoot $backupId
Assert-Target $backupDir "Directory"
$manifestPath = Join-Path $backupDir "manifest"
Assert-Target $manifestPath "File"

$recordedSkill = Get-StateValue $state "skill_sha256"
$recordedSol = Get-StateValue $state "sol_sha256"
$recordedLuna = Get-StateValue $state "luna_sha256"
Assert-Hash $recordedSkill
Assert-Hash $recordedSol
Assert-Hash $recordedLuna
if ((Get-TreeDigest $newSkillTarget) -ne $recordedSkill) {
    throw "installed v0.2 skill was modified; refusing to remove it"
}
if ((Get-FileDigest $newSolTarget) -ne $recordedSol) {
    throw "installed v0.2 Sol controller was modified; refusing to remove it"
}
if ((Get-FileDigest $lunaTarget) -ne $recordedLuna) {
    throw "installed v0.2 Luna agent was modified; refusing to remove it"
}

$manifest = Get-StateMap $manifestPath
if ((Get-StateValue $manifest "version") -ne "2") {
    throw "backup manifest is not v0.2"
}
Assert-BackupEntry $manifest "legacy skill" "legacy_skill_presence" "legacy_skill_sha256" (Join-Path $backupDir "legacy/skill") "Directory"
Assert-BackupEntry $manifest "legacy Sol" "legacy_sol_presence" "legacy_sol_sha256" (Join-Path $backupDir "legacy/sol-planner.toml") "File"
Assert-BackupEntry $manifest "legacy Luna" "legacy_luna_presence" "legacy_luna_sha256" (Join-Path $backupDir "legacy/luna-max-worker.toml") "File"
Assert-BackupEntry $manifest "v020 skill" "v020_skill_presence" "v020_skill_sha256" (Join-Path $backupDir "v020/skill") "Directory"
Assert-BackupEntry $manifest "v020 Sol" "v020_sol_presence" "v020_sol_sha256" (Join-Path $backupDir "v020/sol-controller.toml") "File"
Assert-BackupEntry $manifest "v020 Luna" "v020_luna_presence" "v020_luna_sha256" (Join-Path $backupDir "v020/luna-max-worker.toml") "File"

$configPresence = Get-StateValue $manifest "config_presence"
$configChecksum = Get-StateValue $manifest "config_sha256"
if ($configPresence -ne "present" -and $configPresence -ne "absent") {
    throw "backup manifest has an invalid config presence value"
}
if ($configPresence -eq "present") {
    Assert-Hash $configChecksum
}
elseif (-not [string]::IsNullOrEmpty($configChecksum)) {
    throw "absent config backup has a checksum"
}

$legacySkillPresence = Get-StateValue $manifest "legacy_skill_presence"
$legacySolPresence = Get-StateValue $manifest "legacy_sol_presence"
$legacyLunaPresence = Get-StateValue $manifest "legacy_luna_presence"
$v020SkillPresence = Get-StateValue $manifest "v020_skill_presence"
$v020SolPresence = Get-StateValue $manifest "v020_sol_presence"
$v020LunaPresence = Get-StateValue $manifest "v020_luna_presence"

$restoreLegacySkill = $false
$restoreLegacySol = $false
$restoreV020Skill = $false
$restoreV020Sol = $false
$restoreLuna = $false
$lunaRestoreSource = ""
if ($RestoreLatest) {
    if ($legacySkillPresence -eq "present" -and -not (Test-PathExists $legacySkillTarget)) {
        $restoreLegacySkill = $true
    }
    if ($legacySolPresence -eq "present" -and -not (Test-PathExists $legacySolTarget)) {
        $restoreLegacySol = $true
    }
    if ($v020SkillPresence -eq "present") {
        $restoreV020Skill = $true
    }
    if ($v020SolPresence -eq "present") {
        $restoreV020Sol = $true
    }
    if ($legacyLunaPresence -eq "present") {
        $restoreLuna = $true
        $lunaRestoreSource = Join-Path $backupDir "legacy/luna-max-worker.toml"
    }
    elseif ($v020LunaPresence -eq "present") {
        $restoreLuna = $true
        $lunaRestoreSource = Join-Path $backupDir "v020/luna-max-worker.toml"
    }
}

$transactionDir = Join-Path $stateRoot (".uninstall-" + [Guid]::NewGuid().ToString("N"))
$stateOld = $false
$skillOld = $false
$solOld = $false
$lunaOld = $false
$legacySkillNew = $false
$legacySolNew = $false
$v020SkillNew = $false
$v020SolNew = $false
$lunaNew = $false

try {
    [System.IO.Directory]::CreateDirectory((Join-Path $transactionDir "stage")) | Out-Null
    Assert-Target $transactionDir "Directory"
    Assert-Target (Join-Path $transactionDir "stage") "Directory"

    if ($restoreLegacySkill) {
        Copy-Exact (Join-Path $backupDir "legacy/skill") (Join-Path $transactionDir "stage/legacy-skill")
    }
    if ($restoreLegacySol) {
        Copy-Exact (Join-Path $backupDir "legacy/sol-planner.toml") (Join-Path $transactionDir "stage/legacy-sol.toml")
    }
    if ($restoreV020Skill) {
        Copy-Exact (Join-Path $backupDir "v020/skill") (Join-Path $transactionDir "stage/v020-skill")
    }
    if ($restoreV020Sol) {
        Copy-Exact (Join-Path $backupDir "v020/sol-controller.toml") (Join-Path $transactionDir "stage/v020-sol.toml")
    }
    if ($restoreLuna) {
        Copy-Exact $lunaRestoreSource (Join-Path $transactionDir "stage/luna.toml")
    }

    Move-Item -LiteralPath $stateFile -Destination (Join-Path $transactionDir "old-state")
    $stateOld = $true

    Move-Item -LiteralPath $newSkillTarget -Destination (Join-Path $transactionDir "old-v020-skill")
    $skillOld = $true
    if ($restoreV020Skill) {
        Move-Item -LiteralPath (Join-Path $transactionDir "stage/v020-skill") -Destination $newSkillTarget
        $v020SkillNew = $true
    }

    Move-Item -LiteralPath $newSolTarget -Destination (Join-Path $transactionDir "old-v020-sol")
    $solOld = $true
    if ($restoreV020Sol) {
        Move-Item -LiteralPath (Join-Path $transactionDir "stage/v020-sol.toml") -Destination $newSolTarget
        $v020SolNew = $true
    }

    Move-Item -LiteralPath $lunaTarget -Destination (Join-Path $transactionDir "old-luna")
    $lunaOld = $true
    if ($restoreLuna) {
        Move-Item -LiteralPath (Join-Path $transactionDir "stage/luna.toml") -Destination $lunaTarget
        $lunaNew = $true
    }

    if ($restoreLegacySkill) {
        Move-Item -LiteralPath (Join-Path $transactionDir "stage/legacy-skill") -Destination $legacySkillTarget
        $legacySkillNew = $true
    }
    if ($restoreLegacySol) {
        Move-Item -LiteralPath (Join-Path $transactionDir "stage/legacy-sol.toml") -Destination $legacySolTarget
        $legacySolNew = $true
    }

    Remove-Exact $backupDir
    Remove-Exact $transactionDir
    $transactionDir = ""
}
catch {
    if ($lunaNew -and (Test-PathExists $lunaTarget)) { Remove-Exact $lunaTarget }
    if ($lunaOld -and (Test-PathExists (Join-Path $transactionDir "old-luna"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-luna") -Destination $lunaTarget
    }
    if ($v020SolNew -and (Test-PathExists $newSolTarget)) { Remove-Exact $newSolTarget }
    if ($solOld -and (Test-PathExists (Join-Path $transactionDir "old-v020-sol"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-v020-sol") -Destination $newSolTarget
    }
    if ($v020SkillNew -and (Test-PathExists $newSkillTarget)) { Remove-Exact $newSkillTarget }
    if ($skillOld -and (Test-PathExists (Join-Path $transactionDir "old-v020-skill"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-v020-skill") -Destination $newSkillTarget
    }
    if ($legacySolNew -and (Test-PathExists $legacySolTarget)) { Remove-Exact $legacySolTarget }
    if ($legacySkillNew -and (Test-PathExists $legacySkillTarget)) { Remove-Exact $legacySkillTarget }
    if ($stateOld -and (Test-PathExists (Join-Path $transactionDir "old-state"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-state") -Destination $stateFile
    }
    if ($transactionDir -and (Test-PathExists $transactionDir)) { Remove-Exact $transactionDir }
    throw
}

Remove-EmptyDirectory $backupRoot
Remove-EmptyDirectory $stateRoot

Write-Output "Uninstall path: $newSkillTarget"
Write-Output "Uninstall path: $newSolTarget"
Write-Output "Uninstall path: $lunaTarget"
if ($RestoreLatest) {
    Write-Output "Restore path: $legacySkillTarget"
    Write-Output "Restore path: $legacySolTarget"
}
