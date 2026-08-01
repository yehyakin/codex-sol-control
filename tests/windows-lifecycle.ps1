#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Install = Join-Path $RepoRoot "scripts/install.ps1"
$Validate = Join-Path $RepoRoot "scripts/validate.ps1"
$Uninstall = Join-Path $RepoRoot "scripts/uninstall.ps1"
$TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "codex-sol-luna v030 windows lifecycle " + [Guid]::NewGuid().ToString("N")
)

$OwnedRelativePaths = @(
    ".agents/skills/sol-luna",
    ".agents/skills/orchestrate-sol-luna",
    ".codex/agents/sol-controller.toml",
    ".codex/agents/sol-planner.toml",
    ".codex/agents/luna-max-worker.toml",
    ".codex/sol-luna/install-state",
    ".codex/orchestrate-sol-luna/install-state",
    ".codex/config.toml",
    ".codex/agents/keep-me.toml"
)

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) {
        throw "ASSERTION FAILED: $Message"
    }
}

function Assert-Equal {
    param(
        [AllowNull()][object]$Expected,
        [AllowNull()][object]$Actual,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if ($Expected -ne $Actual) {
        throw "ASSERTION FAILED: $Message (expected '$Expected', actual '$Actual')"
    }
}

function Assert-PathExists {
    param([Parameter(Mandatory = $true)][string]$Path)
    Assert-True (Test-Path -LiteralPath $Path -Force) "expected path to exist: $Path"
}

function Assert-PathAbsent {
    param([Parameter(Mandatory = $true)][string]$Path)
    Assert-True (-not (Test-Path -LiteralPath $Path -Force)) "expected path to be absent: $Path"
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -Force)) {
        [System.IO.Directory]::CreateDirectory($Path) | Out-Null
    }
}

function Write-TestText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )
    Ensure-Directory (Split-Path -Parent $Path)
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Get-FileDigest {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-TreeDigest {
    param([Parameter(Mandatory = $true)][string]$Path)
    $entries = New-Object System.Collections.Generic.List[string]
    $items = @(Get-ChildItem -LiteralPath $Path -Force -Recurse | Sort-Object -Property FullName)
    foreach ($item in $items) {
        $relative = $item.FullName.Substring($Path.Length).TrimStart([char[]]("/\")).Replace("\", "/")
        if ($item.PSIsContainer) {
            $entries.Add("D`t$relative`n")
        }
        else {
            $entries.Add("F`t$relative`t$(Get-FileDigest $item.FullName)`n")
        }
    }
    $text = if ($entries.Count -gt 0) { $entries -join "" } else { "" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-PathFingerprint {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -Force)) {
        return "ABSENT"
    }
    $item = Get-Item -LiteralPath $Path -Force
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        return "REPARSE"
    }
    if ($item.PSIsContainer) {
        return "DIR:$((Get-TreeDigest $Path))"
    }
    return "FILE:$((Get-FileDigest $Path))"
}

function Get-ContractSnapshot {
    param([Parameter(Mandatory = $true)][string]$Home)
    $snapshot = @{}
    foreach ($relative in $OwnedRelativePaths) {
        $snapshot[$relative] = Get-PathFingerprint (Join-Path $Home $relative)
    }
    return $snapshot
}

function Assert-SnapshotEqual {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Expected,
        [Parameter(Mandatory = $true)][hashtable]$Actual,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $expectedKeys = @($Expected.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    $actualKeys = @($Actual.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    Assert-Equal ($expectedKeys -join "`n") ($actualKeys -join "`n") "$Message (snapshot keys)"
    foreach ($key in $expectedKeys) {
        Assert-Equal $Expected[$key] $Actual[$key] "$Message ($key)"
    }
}

function Get-UserMarkers {
    param([Parameter(Mandatory = $true)][string]$Home)
    $config = Join-Path $Home ".codex/config.toml"
    $unrelated = Join-Path $Home ".codex/agents/keep-me.toml"
    return @{
        Config = Get-FileDigest $config
        Unrelated = Get-FileDigest $unrelated
    }
}

function Assert-UserMarkersPreserved {
    param(
        [Parameter(Mandatory = $true)][string]$Home,
        [Parameter(Mandatory = $true)][hashtable]$Markers
    )
    $current = Get-UserMarkers $Home
    Assert-Equal $Markers.Config $current.Config "config.toml changed"
    Assert-Equal $Markers.Unrelated $current.Unrelated "unrelated agent changed"
}

function Seed-UserFiles {
    param([Parameter(Mandatory = $true)][string]$Home)
    Write-TestText (Join-Path $Home ".codex/config.toml") "model = 'user-owned'`n[features]`nsol_luna = false`n"
    Write-TestText (Join-Path $Home ".codex/agents/keep-me.toml") "name = 'unrelated-agent'`n"
    return Get-UserMarkers $Home
}

function Copy-SourceInstall {
    param([Parameter(Mandatory = $true)][string]$Home)
    $skill = Join-Path $Home ".agents/skills/sol-luna"
    $sol = Join-Path $Home ".codex/agents/sol-controller.toml"
    $luna = Join-Path $Home ".codex/agents/luna-max-worker.toml"
    Ensure-Directory (Split-Path -Parent $skill)
    Ensure-Directory (Split-Path -Parent $sol)
    Copy-Item -LiteralPath (Join-Path $RepoRoot ".agents/skills/sol-luna") -Destination $skill -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot ".codex/agents/sol-controller.toml") -Destination $sol -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot ".codex/agents/luna-max-worker.toml") -Destination $luna -Force
}

function Seed-V020Install {
    param([Parameter(Mandatory = $true)][string]$Home)
    Copy-SourceInstall $Home
    $skill = Join-Path $Home ".agents/skills/sol-luna"
    $sol = Join-Path $Home ".codex/agents/sol-controller.toml"
    $luna = Join-Path $Home ".codex/agents/luna-max-worker.toml"
    $state = Join-Path $Home ".codex/sol-luna/install-state"
    $stateText = (@(
        "version=2",
        "backup_id=v020-seed",
        "skill_sha256=$(Get-TreeDigest $skill)",
        "sol_sha256=$(Get-FileDigest $sol)",
        "luna_sha256=$(Get-FileDigest $luna)"
    ) -join "`n") + "`n"
    Write-TestText $state $stateText
    $backup = Join-Path $Home ".codex/sol-luna/backups/v020-seed"
    Ensure-Directory $backup
    Write-TestText (Join-Path $backup "manifest") "version=2`n"
}

function Seed-V01Install {
    param([Parameter(Mandatory = $true)][string]$Home)
    $skill = Join-Path $Home ".agents/skills/orchestrate-sol-luna"
    $sol = Join-Path $Home ".codex/agents/sol-planner.toml"
    $luna = Join-Path $Home ".codex/agents/luna-max-worker.toml"
    $state = Join-Path $Home ".codex/orchestrate-sol-luna/install-state"
    Ensure-Directory (Join-Path $skill "agents")
    Ensure-Directory (Join-Path $skill "references")
    Write-TestText (Join-Path $skill "SKILL.md") "---`nname: orchestrate-sol-luna`ndescription: legacy`n---`nlegacy skill`n"
    Write-TestText (Join-Path $skill "agents/openai.yaml") "legacy: true`n"
    Write-TestText (Join-Path $skill "references/routing-protocol.md") "legacy protocol`n"
    Write-TestText $sol "name = 'sol-planner'`nmodel = 'gpt-5.6-sol'`n"
    Ensure-Directory (Split-Path -Parent $luna)
    Copy-Item -LiteralPath (Join-Path $RepoRoot ".codex/agents/luna-max-worker.toml") -Destination $luna -Force
    $stateText = (@(
        "version=1",
        "backup_id=v01-seed",
        "skill_sha256=$(Get-TreeDigest $skill)",
        "sol_sha256=$(Get-FileDigest $sol)",
        "luna_sha256=$(Get-FileDigest $luna)"
    ) -join "`n") + "`n"
    Write-TestText $state $stateText
}

function Invoke-LifecycleScript {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Home,
        [string[]]$Arguments = @(),
        [string]$Failpoint = ""
    )
    $oldHome = Get-Item Env:ORCHESTRATE_HOME -ErrorAction SilentlyContinue
    $oldFailpoint = Get-Item Env:ORCHESTRATE_FAILPOINT -ErrorAction SilentlyContinue
    try {
        $env:ORCHESTRATE_HOME = $Home
        if ([string]::IsNullOrEmpty($Failpoint)) {
            Remove-Item Env:ORCHESTRATE_FAILPOINT -ErrorAction SilentlyContinue
        }
        else {
            $env:ORCHESTRATE_FAILPOINT = $Failpoint
        }
        & $Path @Arguments | Out-Null
    }
    finally {
        if ($null -eq $oldHome) {
            Remove-Item Env:ORCHESTRATE_HOME -ErrorAction SilentlyContinue
        }
        else {
            $env:ORCHESTRATE_HOME = $oldHome.Value
        }
        if ($null -eq $oldFailpoint) {
            Remove-Item Env:ORCHESTRATE_FAILPOINT -ErrorAction SilentlyContinue
        }
        else {
            $env:ORCHESTRATE_FAILPOINT = $oldFailpoint.Value
        }
    }
}

function Assert-LifecycleFails {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Home,
        [string[]]$Arguments = @(),
        [string]$Failpoint = "",
        [string]$ExpectedError = "",
        [Parameter(Mandatory = $true)][string]$Message
    )
    $failed = $false
    try {
        Invoke-LifecycleScript -Path $Path -Home $Home -Arguments $Arguments -Failpoint $Failpoint
    }
    catch {
        $failed = $true
        if (-not [string]::IsNullOrEmpty($ExpectedError)) {
            Assert-True ($_.Exception.Message -match $ExpectedError) "$Message produced an unexpected error"
        }
    }
    Assert-True $failed $Message
}

function Invoke-Install {
    param([Parameter(Mandatory = $true)][string]$Home)
    Invoke-LifecycleScript -Path $Install -Home $Home
}

function Invoke-Validate {
    param([Parameter(Mandatory = $true)][string]$Home)
    Invoke-LifecycleScript -Path $Validate -Home $Home
}

function Invoke-Uninstall {
    param(
        [Parameter(Mandatory = $true)][string]$Home,
        [switch]$RestoreLatest
    )
    if ($RestoreLatest) {
        Invoke-LifecycleScript -Path $Uninstall -Home $Home -Arguments @("-RestoreLatest")
    }
    else {
        Invoke-LifecycleScript -Path $Uninstall -Home $Home
    }
}

function Assert-Installed {
    param([Parameter(Mandatory = $true)][string]$Home)
    Assert-PathExists (Join-Path $Home ".agents/skills/sol-luna")
    Assert-PathExists (Join-Path $Home ".codex/agents/sol-controller.toml")
    Assert-PathExists (Join-Path $Home ".codex/agents/luna-max-worker.toml")
    $state = Join-Path $Home ".codex/sol-luna/install-state"
    Assert-PathExists $state
    $stateText = Get-Content -LiteralPath $state -Raw
    Assert-True ($stateText -match "(?m)^version=2\s*$") "install state is not version 2"
}

function Assert-Uninstalled {
    param([Parameter(Mandatory = $true)][string]$Home)
    Assert-PathAbsent (Join-Path $Home ".agents/skills/sol-luna")
    Assert-PathAbsent (Join-Path $Home ".codex/agents/sol-controller.toml")
    Assert-PathAbsent (Join-Path $Home ".codex/agents/luna-max-worker.toml")
    Assert-PathAbsent (Join-Path $Home ".codex/sol-luna/install-state")
}

function Test-ModifiedV01MigrationPreservesUserTargets {
    $home = Join-Path $TestRoot "modified v0.1 home"
    $markers = Seed-UserFiles $home
    Seed-V01Install $home
    $legacySkill = Join-Path $home ".agents/skills/orchestrate-sol-luna"
    $legacySkillFile = Join-Path $legacySkill "SKILL.md"
    $legacySol = Join-Path $home ".codex/agents/sol-planner.toml"

    [System.IO.File]::AppendAllText($legacySkillFile, "`nuser modification`n")
    [System.IO.File]::AppendAllText($legacySol, "`nuser modification`n")
    $modifiedSkill = Get-PathFingerprint $legacySkill
    $modifiedSol = Get-PathFingerprint $legacySol

    Invoke-Install $home
    Assert-Installed $home
    Assert-Equal $modifiedSkill (Get-PathFingerprint $legacySkill) "modified v0.1 skill was not preserved"
    Assert-Equal $modifiedSol (Get-PathFingerprint $legacySol) "modified v0.1 Sol agent was not preserved"
    Assert-UserMarkersPreserved $home $markers
}

function Test-FilesystemRootRefusal {
    $filesystemRoot = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($TestRoot))
    $before = Get-ContractSnapshot $filesystemRoot

    Assert-LifecycleFails -Path $Install -Home $filesystemRoot -ExpectedError "filesystem root" -Message "install accepted the filesystem root"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $filesystemRoot) "filesystem-root refusal changed the root"
}

function Try-CreateTestJunction {
    param(
        [Parameter(Mandatory = $true)][string]$Link,
        [Parameter(Mandatory = $true)][string]$Target
    )
    try {
        $command = 'mklink /J "{0}" "{1}"' -f $Link, $Target
        & cmd.exe /c $command 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0 -or -not (Test-Path -LiteralPath $Link -Force)) {
            return $false
        }
        $item = Get-Item -LiteralPath $Link -Force
        return (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
    }
    catch {
        return $false
    }
}

function Remove-TestJunction {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-Path -LiteralPath $Path -Force) {
        & cmd.exe /c ('rmdir /s /q "{0}"' -f $Path) 2>&1 | Out-Null
    }
}

function Test-ReparsePointRefusal {
    $target = Join-Path $TestRoot "junction target"
    $link = Join-Path $TestRoot "junction home"
    $markers = Seed-UserFiles $target

    if (-not (Try-CreateTestJunction -Link $link -Target $target)) {
        Write-Output "Windows lifecycle contract: SKIP reparse-point refusal; current Windows process cannot create a test junction"
        return
    }

    try {
        $before = Get-ContractSnapshot $target
        Assert-LifecycleFails -Path $Install -Home $link -ExpectedError "(?i)(unsafe install directory|reparse point)" -Message "install accepted an ORCHESTRATE_HOME reparse point"
        Assert-SnapshotEqual $before (Get-ContractSnapshot $target) "reparse-point refusal changed the junction target"
        Assert-UserMarkersPreserved $target $markers
        $item = Get-Item -LiteralPath $link -Force
        Assert-True (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) "test junction was mutated"
    }
    finally {
        Remove-TestJunction $link
    }
}

function Test-FreshRepeatInstallAndSpaces {
    $home = Join-Path $TestRoot "fresh home with spaces"
    $markers = Seed-UserFiles $home

    Invoke-Install $home
    Assert-Installed $home
    Assert-UserMarkersPreserved $home $markers
    Invoke-Validate $home
    Invoke-Install $home
    Assert-Installed $home
    Assert-UserMarkersPreserved $home $markers
    Invoke-Uninstall $home
    Assert-Uninstalled $home
    Assert-UserMarkersPreserved $home $markers
    Invoke-Install $home
    Assert-Installed $home
    Invoke-Uninstall $home -RestoreLatest
    Assert-Uninstalled $home
    Assert-UserMarkersPreserved $home $markers
}

function Test-V020Upgrade {
    $home = Join-Path $TestRoot "v0.2 upgrade home"
    $markers = Seed-UserFiles $home
    Seed-V020Install $home

    Invoke-Install $home
    Assert-Installed $home
    Assert-UserMarkersPreserved $home $markers
}

function Test-V01MigrationAndRestoreLatest {
    $home = Join-Path $TestRoot "v0.1 migration home"
    $markers = Seed-UserFiles $home
    Seed-V01Install $home
    $legacySkill = Join-Path $home ".agents/skills/orchestrate-sol-luna"
    $legacySol = Join-Path $home ".codex/agents/sol-planner.toml"
    $legacyLuna = Join-Path $home ".codex/agents/luna-max-worker.toml"
    $oldSkill = Get-PathFingerprint $legacySkill
    $oldSol = Get-PathFingerprint $legacySol
    $oldLuna = Get-PathFingerprint $legacyLuna

    Invoke-Install $home
    Assert-Installed $home
    Assert-PathAbsent $legacySkill
    Assert-PathAbsent $legacySol
    Assert-UserMarkersPreserved $home $markers

    Invoke-Uninstall $home -RestoreLatest
    Assert-Uninstalled $home
    Assert-Equal $oldSkill (Get-PathFingerprint $legacySkill) "v0.1 skill was not restored"
    Assert-Equal $oldSol (Get-PathFingerprint $legacySol) "v0.1 Sol agent was not restored"
    Assert-Equal $oldLuna (Get-PathFingerprint $legacyLuna) "shared Luna was not restored"
    Assert-UserMarkersPreserved $home $markers
}

function Test-ModifiedCurrentTargetRefusal {
    $home = Join-Path $TestRoot "modified target home"
    $markers = Seed-UserFiles $home
    Invoke-Install $home
    $modified = Join-Path $home ".codex/agents/sol-controller.toml"
    [System.IO.File]::AppendAllText($modified, "`nuser modification`n")
    $before = Get-ContractSnapshot $home

    Assert-LifecycleFails -Path $Uninstall -Home $home -Message "checksum-mismatched current target was removed"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $home) "modified-target refusal changed the home"
    Assert-UserMarkersPreserved $home $markers
}

function Test-RollbackFailpoint {
    $home = Join-Path $TestRoot "rollback failpoint home"
    $markers = Seed-UserFiles $home
    $before = Get-ContractSnapshot $home

    Assert-LifecycleFails -Path $Install -Home $home -Failpoint "after-replace" -Message "after-replace failpoint did not fail"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $home) "rollback did not restore the isolated home"
    Assert-UserMarkersPreserved $home $markers
}

function Test-IsolatedHomes {
    $homeA = Join-Path $TestRoot "isolated home A"
    $homeB = Join-Path $TestRoot "isolated home B"
    $markersA = Seed-UserFiles $homeA
    $markersB = Seed-UserFiles $homeB

    Invoke-Install $homeA
    Assert-Installed $homeA
    Assert-PathAbsent (Join-Path $homeB ".codex/sol-luna/install-state")
    Invoke-Install $homeB
    Assert-Installed $homeB
    Assert-UserMarkersPreserved $homeA $markersA
    Assert-UserMarkersPreserved $homeB $markersB

    Invoke-Uninstall $homeA
    Assert-Uninstalled $homeA
    Assert-Installed $homeB
    Invoke-Validate $homeB
    Invoke-Uninstall $homeB
    Assert-Uninstalled $homeB
}

try {
    [System.IO.Directory]::CreateDirectory($TestRoot) | Out-Null

    foreach ($required in @($Install, $Validate, $Uninstall)) {
        Assert-PathExists $required
    }

    Test-FreshRepeatInstallAndSpaces
    Test-V020Upgrade
    Test-V01MigrationAndRestoreLatest
    Test-ModifiedV01MigrationPreservesUserTargets
    Test-ModifiedCurrentTargetRefusal
    Test-RollbackFailpoint
    Test-IsolatedHomes
    Test-FilesystemRootRefusal
    Test-ReparsePointRefusal

    Write-Output "Windows lifecycle contract: PASS"
}
finally {
    if (Test-Path -LiteralPath $TestRoot -Force) {
        Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
