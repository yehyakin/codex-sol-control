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
        if ($line -notmatch "^(?<key>[A-Za-z_][A-Za-z0-9_]*)=(?<value>.*)$") {
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

$newSkillTarget = Join-Path $baseDir ".agents/skills/sol-control"
$compatSkillTarget = Join-Path $baseDir ".agents/skills/sol-luna"
$newSolTarget = Join-Path $baseDir ".codex/agents/sol-controller.toml"
$lunaTarget = Join-Path $baseDir ".codex/agents/luna-max-worker.toml"
$terraTarget = Join-Path $baseDir ".codex/agents/terra-high-worker.toml"
$legacySkillTarget = Join-Path $baseDir ".agents/skills/orchestrate-sol-luna"
$legacySolTarget = Join-Path $baseDir ".codex/agents/sol-planner.toml"
$codexDir = Join-Path $baseDir ".codex"
$agentsDir = Join-Path $codexDir "agents"
$configTarget = Join-Path $codexDir "config.toml"
$stateRoot = Join-Path $codexDir "sol-control"
$stateFile = Join-Path $stateRoot "install-state"
$backupRoot = Join-Path $stateRoot "backups"
$previousStateRoot = Join-Path $codexDir "sol-luna"
$previousStateFile = Join-Path $previousStateRoot "install-state"
$legacyStateRoot = Join-Path $codexDir "orchestrate-sol-luna"
$legacyStateFile = Join-Path $legacyStateRoot "install-state"

foreach ($directory in @(
    (Join-Path $baseDir ".agents"),
    (Join-Path $baseDir ".agents/skills"),
    $codexDir,
    $agentsDir,
    $stateRoot,
    $backupRoot,
    $previousStateRoot,
    $legacyStateRoot
)) {
    if (Test-PathExists $directory) {
        Assert-Target $directory "Directory"
    }
}

if (-not (Test-Path -LiteralPath $stateRoot -PathType Container) -or
    -not (Test-Path -LiteralPath $stateFile -PathType Leaf)) {
    throw "no v0.4 installation state was found"
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
Assert-Target $compatSkillTarget "Directory"
Assert-Target $newSolTarget "File"
Assert-Target $lunaTarget "File"
Assert-Target $terraTarget "File"
Assert-Target $legacySkillTarget "Directory"
Assert-Target $legacySolTarget "File"
if (Test-PathExists $legacyStateFile) { Assert-Target $legacyStateFile "File" }
if (Test-PathExists $previousStateFile) { Assert-Target $previousStateFile "File" }

$state = Get-StateMap $stateFile
if ((Get-StateValue $state "version") -ne "3") {
    throw "install state is not v0.4"
}
$backupId = Get-StateValue $state "backup_id"
Assert-BackupId $backupId
$backupDir = Join-Path $backupRoot $backupId
Assert-Target $backupDir "Directory"
$manifestPath = Join-Path $backupDir "manifest"
Assert-Target $manifestPath "File"

$recordedSkill = Get-StateValue $state "skill_sha256"
$recordedCompatSkill = Get-StateValue $state "compat_skill_sha256"
$recordedSol = Get-StateValue $state "sol_sha256"
$recordedLuna = Get-StateValue $state "luna_sha256"
$recordedTerra = if ($state.ContainsKey("terra_sha256")) { [string]$state["terra_sha256"] } else { "" }
Assert-Hash $recordedSkill
Assert-Hash $recordedCompatSkill
Assert-Hash $recordedSol
Assert-Hash $recordedLuna
if ($recordedTerra) { Assert-Hash $recordedTerra }
if ((Get-TreeDigest $newSkillTarget) -ne $recordedSkill) {
    throw "installed v0.4 skill was modified; refusing to remove it"
}
if ((Get-TreeDigest $compatSkillTarget) -ne $recordedCompatSkill) {
    throw "installed compatibility skill was modified; refusing to remove it"
}
if ((Get-FileDigest $newSolTarget) -ne $recordedSol) {
    throw "installed v0.4 Sol controller was modified; refusing to remove it"
}
if ((Get-FileDigest $lunaTarget) -ne $recordedLuna) {
    throw "installed v0.4 Luna agent was modified; refusing to remove it"
}
if ($recordedTerra -and ((-not (Test-Path -LiteralPath $terraTarget -PathType Leaf)) -or (Get-FileDigest $terraTarget) -ne $recordedTerra)) {
    throw "installed v0.4 Terra agent was modified; refusing to remove it"
}

$manifest = Get-StateMap $manifestPath
if ((Get-StateValue $manifest "version") -ne "3") {
    throw "backup manifest is not v0.4"
}
Assert-BackupEntry $manifest "legacy skill" "legacy_skill_presence" "legacy_skill_sha256" (Join-Path $backupDir "legacy/skill") "Directory"
Assert-BackupEntry $manifest "legacy Sol" "legacy_sol_presence" "legacy_sol_sha256" (Join-Path $backupDir "legacy/sol-planner.toml") "File"
Assert-BackupEntry $manifest "legacy Luna" "legacy_luna_presence" "legacy_luna_sha256" (Join-Path $backupDir "legacy/luna-max-worker.toml") "File"
if ($manifest.ContainsKey("legacy_state_presence") -or $manifest.ContainsKey("legacy_state_sha256")) {
    if (-not $manifest.ContainsKey("legacy_state_presence") -or -not $manifest.ContainsKey("legacy_state_sha256")) {
        throw "backup manifest is incomplete"
    }
    Assert-BackupEntry $manifest "legacy install state" "legacy_state_presence" "legacy_state_sha256" (Join-Path $backupDir "legacy/install-state") "File"
    $legacyStatePresence = Get-StateValue $manifest "legacy_state_presence"
}
else {
    # Older v0.4 manifests predate legacy install-state archival.
    $legacyStatePresence = "absent"
}
Assert-BackupEntry $manifest "previous install state" "previous_state_presence" "previous_state_sha256" (Join-Path $backupDir "previous-install-state") "File"
Assert-BackupEntry $manifest "compatibility skill" "compat_skill_presence" "compat_skill_sha256" (Join-Path $backupDir "compat-skill") "Directory"
Assert-BackupEntry $manifest "v040 install state" "v040_state_presence" "v040_state_sha256" (Join-Path $backupDir "v040/install-state") "File"
Assert-BackupEntry $manifest "v040 skill" "v040_skill_presence" "v040_skill_sha256" (Join-Path $backupDir "v040/skill") "Directory"
Assert-BackupEntry $manifest "v040 Sol" "v040_sol_presence" "v040_sol_sha256" (Join-Path $backupDir "v040/sol-controller.toml") "File"
Assert-BackupEntry $manifest "v040 Luna" "v040_luna_presence" "v040_luna_sha256" (Join-Path $backupDir "v040/luna-max-worker.toml") "File"
if ($recordedTerra) {
    Assert-BackupEntry $manifest "v040 Terra" "v040_terra_presence" "v040_terra_sha256" (Join-Path $backupDir "v040/terra-high-worker.toml") "File"
}

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
$previousStatePresence = Get-StateValue $manifest "previous_state_presence"
$compatSkillPresence = Get-StateValue $manifest "compat_skill_presence"
$v040StatePresence = Get-StateValue $manifest "v040_state_presence"
$v040SkillPresence = Get-StateValue $manifest "v040_skill_presence"
$v040SolPresence = Get-StateValue $manifest "v040_sol_presence"
$v040LunaPresence = Get-StateValue $manifest "v040_luna_presence"
$v040TerraPresence = if ($recordedTerra) { Get-StateValue $manifest "v040_terra_presence" } else { "absent" }

$restoreLegacySkill = $false
$restoreLegacySol = $false
$restoreLegacyState = $false
$restorePreviousState = $false
$restoreCompatSkill = $false
$restoreV040State = $false
$restoreV040Skill = $false
$restoreV040Sol = $false
$restoreLuna = $false
$restoreTerra = $false
$lunaRestoreSource = ""
if ($RestoreLatest) {
    if ($previousStatePresence -eq "present") {
        if (Test-PathExists $previousStateFile) {
            throw "previous install state already exists; refusing to overwrite it"
        }
        $restorePreviousState = $true
    }
    if ($legacyStatePresence -eq "present") {
        if (Test-PathExists $legacyStateFile) {
            throw "legacy install state already exists; refusing to overwrite it"
        }
        $restoreLegacyState = $true
    }
    if ($legacySkillPresence -eq "present" -and -not (Test-PathExists $legacySkillTarget)) {
        $restoreLegacySkill = $true
    }
    if ($legacySolPresence -eq "present" -and -not (Test-PathExists $legacySolTarget)) {
        $restoreLegacySol = $true
    }
    if ($v040SkillPresence -eq "present") {
        $restoreV040Skill = $true
    }
    if ($compatSkillPresence -eq "present") {
        $restoreCompatSkill = $true
    }
    if ($v040StatePresence -eq "present") {
        $restoreV040State = $true
    }
    if ($v040SolPresence -eq "present") {
        $restoreV040Sol = $true
    }
    if ($v040LunaPresence -eq "present") {
        $restoreLuna = $true
        $lunaRestoreSource = Join-Path $backupDir "v040/luna-max-worker.toml"
    }
    elseif ($legacyLunaPresence -eq "present") {
        $restoreLuna = $true
        $lunaRestoreSource = Join-Path $backupDir "legacy/luna-max-worker.toml"
    }
    if ($v040TerraPresence -eq "present") { $restoreTerra = $true }
}

$transactionDir = Join-Path $stateRoot (".uninstall-" + [Guid]::NewGuid().ToString("N"))
$stateOld = $false
$v040StateNew = $false
$skillOld = $false
$compatSkillOld = $false
$solOld = $false
$lunaOld = $false
$terraOld = $false
$legacySkillNew = $false
$legacySolNew = $false
$legacyStateNew = $false
$legacyStateRootNew = $false
$previousStateNew = $false
$previousStateRootNew = $false
$compatSkillNew = $false
$v040SkillNew = $false
$v040SolNew = $false
$lunaNew = $false
$terraNew = $false

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
    if ($restoreLegacyState) {
        Copy-Exact (Join-Path $backupDir "legacy/install-state") (Join-Path $transactionDir "stage/legacy-install-state")
    }
    if ($restorePreviousState) {
        Copy-Exact (Join-Path $backupDir "previous-install-state") (Join-Path $transactionDir "stage/previous-install-state")
    }
    if ($restoreCompatSkill) {
        Copy-Exact (Join-Path $backupDir "compat-skill") (Join-Path $transactionDir "stage/compat-skill")
    }
    if ($restoreV040State) {
        Copy-Exact (Join-Path $backupDir "v040/install-state") (Join-Path $transactionDir "stage/v040-install-state")
    }
    if ($restoreV040Skill) {
        Copy-Exact (Join-Path $backupDir "v040/skill") (Join-Path $transactionDir "stage/v040-skill")
    }

    Move-Item -LiteralPath $compatSkillTarget -Destination (Join-Path $transactionDir "old-compat-skill")
    $compatSkillOld = $true
    if ($restoreCompatSkill) {
        Move-Item -LiteralPath (Join-Path $transactionDir "stage/compat-skill") -Destination $compatSkillTarget
        $compatSkillNew = $true
    }
    if ($restoreV040Sol) {
        Copy-Exact (Join-Path $backupDir "v040/sol-controller.toml") (Join-Path $transactionDir "stage/v040-sol.toml")
    }
    if ($restoreLuna) {
        Copy-Exact $lunaRestoreSource (Join-Path $transactionDir "stage/luna.toml")
    }
    if ($restoreTerra) {
        Copy-Exact (Join-Path $backupDir "v040/terra-high-worker.toml") (Join-Path $transactionDir "stage/terra.toml")
    }

    Move-Item -LiteralPath $stateFile -Destination (Join-Path $transactionDir "old-state")
    $stateOld = $true
    if ($restoreV040State) {
        Move-Item -LiteralPath (Join-Path $transactionDir "stage/v040-install-state") -Destination $stateFile
        $v040StateNew = $true
    }

    Move-Item -LiteralPath $newSkillTarget -Destination (Join-Path $transactionDir "old-v040-skill")
    $skillOld = $true
    if ($restoreV040Skill) {
        Move-Item -LiteralPath (Join-Path $transactionDir "stage/v040-skill") -Destination $newSkillTarget
        $v040SkillNew = $true
    }

    Move-Item -LiteralPath $newSolTarget -Destination (Join-Path $transactionDir "old-v040-sol")
    $solOld = $true
    if ($restoreV040Sol) {
        Move-Item -LiteralPath (Join-Path $transactionDir "stage/v040-sol.toml") -Destination $newSolTarget
        $v040SolNew = $true
    }

    Move-Item -LiteralPath $lunaTarget -Destination (Join-Path $transactionDir "old-luna")
    $lunaOld = $true
    if ($restoreLuna) {
        Move-Item -LiteralPath (Join-Path $transactionDir "stage/luna.toml") -Destination $lunaTarget
        $lunaNew = $true
    }

    if ($recordedTerra) {
        Move-Item -LiteralPath $terraTarget -Destination (Join-Path $transactionDir "old-terra")
        $terraOld = $true
        if ($restoreTerra) {
            Move-Item -LiteralPath (Join-Path $transactionDir "stage/terra.toml") -Destination $terraTarget
            $terraNew = $true
        }
    }

    if ($restoreLegacySkill) {
        Move-Item -LiteralPath (Join-Path $transactionDir "stage/legacy-skill") -Destination $legacySkillTarget
        $legacySkillNew = $true
    }
    if ($restoreLegacySol) {
        Move-Item -LiteralPath (Join-Path $transactionDir "stage/legacy-sol.toml") -Destination $legacySolTarget
        $legacySolNew = $true
    }
    if ($restoreLegacyState) {
        if (-not (Test-PathExists $legacyStateRoot)) {
            [System.IO.Directory]::CreateDirectory($legacyStateRoot) | Out-Null
            $legacyStateRootNew = $true
        }
        Move-Item -LiteralPath (Join-Path $transactionDir "stage/legacy-install-state") -Destination $legacyStateFile
        $legacyStateNew = $true
    }
    if ($restorePreviousState) {
        if (-not (Test-PathExists $previousStateRoot)) {
            [System.IO.Directory]::CreateDirectory($previousStateRoot) | Out-Null
            $previousStateRootNew = $true
        }
        Move-Item -LiteralPath (Join-Path $transactionDir "stage/previous-install-state") -Destination $previousStateFile
        $previousStateNew = $true
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
    if ($terraNew -and (Test-PathExists $terraTarget)) { Remove-Exact $terraTarget }
    if ($terraOld -and (Test-PathExists (Join-Path $transactionDir "old-terra"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-terra") -Destination $terraTarget
    }
    if ($v040SolNew -and (Test-PathExists $newSolTarget)) { Remove-Exact $newSolTarget }
    if ($solOld -and (Test-PathExists (Join-Path $transactionDir "old-v040-sol"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-v040-sol") -Destination $newSolTarget
    }
    if ($v040SkillNew -and (Test-PathExists $newSkillTarget)) { Remove-Exact $newSkillTarget }
    if ($skillOld -and (Test-PathExists (Join-Path $transactionDir "old-v040-skill"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-v040-skill") -Destination $newSkillTarget
    }
    if ($compatSkillNew -and (Test-PathExists $compatSkillTarget)) { Remove-Exact $compatSkillTarget }
    if ($compatSkillOld -and (Test-PathExists (Join-Path $transactionDir "old-compat-skill"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-compat-skill") -Destination $compatSkillTarget
    }
    if ($legacySolNew -and (Test-PathExists $legacySolTarget)) { Remove-Exact $legacySolTarget }
    if ($legacySkillNew -and (Test-PathExists $legacySkillTarget)) { Remove-Exact $legacySkillTarget }
    if ($legacyStateNew -and (Test-PathExists $legacyStateFile)) { Remove-Exact $legacyStateFile }
    if ($legacyStateRootNew) { Remove-EmptyDirectory $legacyStateRoot }
    if ($previousStateNew -and (Test-PathExists $previousStateFile)) { Remove-Exact $previousStateFile }
    if ($previousStateRootNew) { Remove-EmptyDirectory $previousStateRoot }
    if ($v040StateNew -and (Test-PathExists $stateFile)) { Remove-Exact $stateFile }
    if ($stateOld -and (Test-PathExists (Join-Path $transactionDir "old-state"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-state") -Destination $stateFile
    }
    if ($transactionDir -and (Test-PathExists $transactionDir)) { Remove-Exact $transactionDir }
    throw
}

Remove-EmptyDirectory $backupRoot
Remove-EmptyDirectory $stateRoot

Write-Output "Uninstall path: $newSkillTarget"
Write-Output "Uninstall path: $compatSkillTarget"
Write-Output "Uninstall path: $newSolTarget"
Write-Output "Uninstall path: $lunaTarget"
if ($recordedTerra) { Write-Output "Uninstall path: $terraTarget" }
if ($RestoreLatest) {
    Write-Output "Restore path: $legacySkillTarget"
    Write-Output "Restore path: $legacySolTarget"
    if ($restoreCompatSkill) { Write-Output "Restore path: $compatSkillTarget" }
    if ($restorePreviousState) { Write-Output "Restore path: $previousStateFile" }
    if ($restoreV040State) { Write-Output "Restore path: $stateFile" }
    if ($restoreLegacyState) { Write-Output "Restore path: $legacyStateFile" }
}
