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
    "codex-sol-control v050 windows lifecycle " + [Guid]::NewGuid().ToString("N")
)

$OwnedRelativePaths = @(
    ".agents/skills/sol-control",
    ".agents/skills/sol-luna",
    ".agents/skills/orchestrate-sol-luna",
    ".codex/agents/sol-controller.toml",
    ".codex/agents/sol-planner.toml",
    ".codex/agents/luna-max-worker.toml",
    ".codex/agents/terra-high-worker.toml",
    ".codex/sol-control/install-state",
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
    Assert-True (Test-Path -LiteralPath $Path) "expected path to exist: $Path"
}

function Assert-PathAbsent {
    param([Parameter(Mandatory = $true)][string]$Path)
    Assert-True (-not (Test-Path -LiteralPath $Path)) "expected path to be absent: $Path"
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
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
    if (-not (Test-Path -LiteralPath $Path)) {
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
    param([Parameter(Mandatory = $true)][string]$TestHome)
    $snapshot = @{}
    foreach ($relative in $OwnedRelativePaths) {
        $snapshot[$relative] = Get-PathFingerprint (Join-Path $TestHome $relative)
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
    param([Parameter(Mandatory = $true)][string]$TestHome)
    $config = Join-Path $TestHome ".codex/config.toml"
    $unrelated = Join-Path $TestHome ".codex/agents/keep-me.toml"
    return @{
        Config = Get-FileDigest $config
        Unrelated = Get-FileDigest $unrelated
    }
}

function Assert-UserMarkersPreserved {
    param(
        [Parameter(Mandatory = $true)][string]$TestHome,
        [Parameter(Mandatory = $true)][hashtable]$Markers
    )
    $current = Get-UserMarkers $TestHome
    Assert-Equal $Markers.Config $current.Config "config.toml changed"
    Assert-Equal $Markers.Unrelated $current.Unrelated "unrelated agent changed"
}

function Seed-UserFiles {
    param([Parameter(Mandatory = $true)][string]$TestHome)
    Write-TestText (Join-Path $TestHome ".codex/config.toml") "model = 'user-owned'`n[features]`nsol_luna = false`n"
    Write-TestText (Join-Path $TestHome ".codex/agents/keep-me.toml") "name = 'unrelated-agent'`n"
    return Get-UserMarkers $TestHome
}

function Copy-SourceInstall {
    param([Parameter(Mandatory = $true)][string]$TestHome)
    $skill = Join-Path $TestHome ".agents/skills/sol-luna"
    $sol = Join-Path $TestHome ".codex/agents/sol-controller.toml"
    $luna = Join-Path $TestHome ".codex/agents/luna-max-worker.toml"
    $terra = Join-Path $TestHome ".codex/agents/terra-high-worker.toml"
    Ensure-Directory (Split-Path -Parent $skill)
    Ensure-Directory (Split-Path -Parent $sol)
    Ensure-Directory (Join-Path $skill "agents")
    Write-TestText (Join-Path $skill "SKILL.md") "---`nname: sol-luna`ndescription: v0.3 full skill`n---`nlegacy full skill`n"
    Write-TestText (Join-Path $skill "agents/openai.yaml") "interface:`n  default_prompt: use `$sol-luna`n"
    Copy-Item -LiteralPath (Join-Path $RepoRoot ".codex/agents/sol-controller.toml") -Destination $sol -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot ".codex/agents/luna-max-worker.toml") -Destination $luna -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot ".codex/agents/terra-high-worker.toml") -Destination $terra -Force
}

function Seed-V040Install {
    param([Parameter(Mandatory = $true)][string]$TestHome)
    $skill = Join-Path $TestHome ".agents/skills/sol-control"
    $compatSkill = Join-Path $TestHome ".agents/skills/sol-luna"
    $sol = Join-Path $TestHome ".codex/agents/sol-controller.toml"
    $luna = Join-Path $TestHome ".codex/agents/luna-max-worker.toml"
    $terra = Join-Path $TestHome ".codex/agents/terra-high-worker.toml"
    Ensure-Directory (Split-Path -Parent $skill)
    Ensure-Directory (Join-Path $compatSkill "agents")
    Ensure-Directory (Split-Path -Parent $sol)
    Copy-Item -LiteralPath (Join-Path $RepoRoot ".agents/skills/sol-control") -Destination $skill -Recurse -Force
    Write-TestText (Join-Path $compatSkill "SKILL.md") "---`nname: sol-luna`ndescription: v0.4 compatibility alias`n---`nredirect to `$sol-control`n"
    Write-TestText (Join-Path $compatSkill "agents/openai.yaml") "interface:`n  default_prompt: use `$sol-control`n"
    Copy-Item -LiteralPath (Join-Path $RepoRoot ".codex/agents/sol-controller.toml") -Destination $sol -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot ".codex/agents/luna-max-worker.toml") -Destination $luna -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot ".codex/agents/terra-high-worker.toml") -Destination $terra -Force
    Write-TestText (Join-Path $TestHome ".codex/sol-control/install-state") ((@(
        "version=3",
        "backup_id=v040-seed",
        "skill_sha256=$(Get-TreeDigest $skill)",
        "compat_skill_sha256=$(Get-TreeDigest $compatSkill)",
        "sol_sha256=$(Get-FileDigest $sol)",
        "luna_sha256=$(Get-FileDigest $luna)",
        "terra_sha256=$(Get-FileDigest $terra)"
    ) -join "`n") + "`n")
}

function Seed-V030Install {
    param([Parameter(Mandatory = $true)][string]$TestHome)
    Copy-SourceInstall $TestHome
    $skill = Join-Path $TestHome ".agents/skills/sol-luna"
    $sol = Join-Path $TestHome ".codex/agents/sol-controller.toml"
    $luna = Join-Path $TestHome ".codex/agents/luna-max-worker.toml"
    $terra = Join-Path $TestHome ".codex/agents/terra-high-worker.toml"
    $state = Join-Path $TestHome ".codex/sol-luna/install-state"
    $stateText = (@(
        "version=2",
        "backup_id=v030-seed",
        "skill_sha256=$(Get-TreeDigest $skill)",
        "sol_sha256=$(Get-FileDigest $sol)",
        "luna_sha256=$(Get-FileDigest $luna)",
        "terra_sha256=$(Get-FileDigest $terra)"
    ) -join "`n") + "`n"
    Write-TestText $state $stateText
    $backup = Join-Path $TestHome ".codex/sol-luna/backups/v030-seed"
    Ensure-Directory $backup
    Ensure-Directory (Join-Path $backup "v030")
    Copy-Item -LiteralPath $skill -Destination (Join-Path $backup "v030/skill") -Recurse -Force
    Copy-Item -LiteralPath $sol -Destination (Join-Path $backup "v030/sol-controller.toml") -Force
    Copy-Item -LiteralPath $luna -Destination (Join-Path $backup "v030/luna-max-worker.toml") -Force
    Copy-Item -LiteralPath $terra -Destination (Join-Path $backup "v030/terra-high-worker.toml") -Force
    Write-TestText (Join-Path $backup "manifest") ((@(
        "version=2",
        "legacy_skill_presence=absent",
        "legacy_skill_sha256=",
        "legacy_sol_presence=absent",
        "legacy_sol_sha256=",
        "legacy_luna_presence=absent",
        "legacy_luna_sha256=",
        "v030_skill_presence=present",
        "v030_skill_sha256=$(Get-TreeDigest $skill)",
        "v030_sol_presence=present",
        "v030_sol_sha256=$(Get-FileDigest $sol)",
        "v030_luna_presence=present",
        "v030_luna_sha256=$(Get-FileDigest $luna)",
        "v030_terra_presence=present",
        "v030_terra_sha256=$(Get-FileDigest $terra)",
        "config_presence=absent",
        "config_sha256="
    ) -join "`n") + "`n")
}

function Seed-V01Install {
    param([Parameter(Mandatory = $true)][string]$TestHome)
    $skill = Join-Path $TestHome ".agents/skills/orchestrate-sol-luna"
    $sol = Join-Path $TestHome ".codex/agents/sol-planner.toml"
    $luna = Join-Path $TestHome ".codex/agents/luna-max-worker.toml"
    $state = Join-Path $TestHome ".codex/orchestrate-sol-luna/install-state"
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
        [Parameter(Mandatory = $true)][string]$TestHome,
        [hashtable]$Parameters = @{},
        [string]$Failpoint = ""
    )
    $oldHome = Get-Item Env:ORCHESTRATE_HOME -ErrorAction SilentlyContinue
    $oldFailpoint = Get-Item Env:ORCHESTRATE_FAILPOINT -ErrorAction SilentlyContinue
    try {
        $env:ORCHESTRATE_HOME = $TestHome
        if ([string]::IsNullOrEmpty($Failpoint)) {
            Remove-Item Env:ORCHESTRATE_FAILPOINT -ErrorAction SilentlyContinue
        }
        else {
            $env:ORCHESTRATE_FAILPOINT = $Failpoint
        }
        & $Path @Parameters | Out-Null
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

function Invoke-CheckProcess {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$TestHome
    )
    $oldHome = Get-Item Env:ORCHESTRATE_HOME -ErrorAction SilentlyContinue
    try {
        $env:ORCHESTRATE_HOME = $TestHome
        $engine = (Get-Process -Id $PID).Path
        if ([string]::IsNullOrWhiteSpace($engine)) {
            $engine = Join-Path $PSHOME "powershell.exe"
        }
        $child = Start-Process -FilePath $engine -ArgumentList @(
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-File",
            $Path,
            "-Check"
        ) -Wait -PassThru -NoNewWindow
        return [int]$child.ExitCode
    }
    finally {
        if ($null -eq $oldHome) {
            Remove-Item Env:ORCHESTRATE_HOME -ErrorAction SilentlyContinue
        }
        else {
            $env:ORCHESTRATE_HOME = $oldHome.Value
        }
    }
}

function Assert-LifecycleFails {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$TestHome,
        [hashtable]$Parameters = @{},
        [string]$Failpoint = "",
        [string]$ExpectedError = "",
        [Parameter(Mandatory = $true)][string]$Message
    )
    $failed = $false
    try {
        Invoke-LifecycleScript -Path $Path -TestHome $TestHome -Parameters $Parameters -Failpoint $Failpoint
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
    param([Parameter(Mandatory = $true)][string]$TestHome)
    Invoke-LifecycleScript -Path $Install -TestHome $TestHome
}

function Invoke-Validate {
    param([Parameter(Mandatory = $true)][string]$TestHome)
    Invoke-LifecycleScript -Path $Validate -TestHome $TestHome
}

function Invoke-Uninstall {
    param(
        [Parameter(Mandatory = $true)][string]$TestHome,
        [switch]$RestoreLatest
    )
    if ($RestoreLatest) {
        Invoke-LifecycleScript -Path $Uninstall -TestHome $TestHome -Parameters @{ RestoreLatest = $true }
    }
    else {
        Invoke-LifecycleScript -Path $Uninstall -TestHome $TestHome
    }
}

function Assert-Installed {
    param([Parameter(Mandatory = $true)][string]$TestHome)
    Assert-PathExists (Join-Path $TestHome ".agents/skills/sol-control")
    Assert-PathAbsent (Join-Path $TestHome ".agents/skills/sol-luna")
    Assert-PathExists (Join-Path $TestHome ".codex/agents/sol-controller.toml")
    Assert-PathExists (Join-Path $TestHome ".codex/agents/luna-max-worker.toml")
    Assert-PathExists (Join-Path $TestHome ".codex/agents/terra-high-worker.toml")
    $state = Join-Path $TestHome ".codex/sol-control/install-state"
    Assert-PathExists $state
    $stateText = Get-Content -LiteralPath $state -Raw
    Assert-True ($stateText -match "(?m)^version=4\s*$") "install state is not version 4"
    Assert-True ($stateText -notmatch "(?m)^compat_skill_sha256=") "v0.5 install state still owns the removed compatibility skill"
    Assert-True ($stateText -match "(?m)^terra_sha256=[0-9a-f]{64}\s*$") "install state has no Terra checksum"
}

function Assert-Uninstalled {
    param(
        [Parameter(Mandatory = $true)][string]$TestHome,
        [switch]$ExpectSharedLuna,
        [switch]$ExpectTerra
    )
    Assert-PathAbsent (Join-Path $TestHome ".agents/skills/sol-control")
    Assert-PathAbsent (Join-Path $TestHome ".agents/skills/sol-luna")
    Assert-PathAbsent (Join-Path $TestHome ".codex/agents/sol-controller.toml")
    if ($ExpectSharedLuna) {
        Assert-PathExists (Join-Path $TestHome ".codex/agents/luna-max-worker.toml")
    }
    else {
        Assert-PathAbsent (Join-Path $TestHome ".codex/agents/luna-max-worker.toml")
    }
    if ($ExpectTerra) {
        Assert-PathExists (Join-Path $TestHome ".codex/agents/terra-high-worker.toml")
    }
    else {
        Assert-PathAbsent (Join-Path $TestHome ".codex/agents/terra-high-worker.toml")
    }
    Assert-PathAbsent (Join-Path $TestHome ".codex/sol-control/install-state")
}

function Test-ModifiedV01MigrationFailsClosed {
    $TestHome = Join-Path $TestRoot "modified v0.1 home"
    $markers = Seed-UserFiles $TestHome
    Seed-V01Install $TestHome
    $legacySkill = Join-Path $TestHome ".agents/skills/orchestrate-sol-luna"
    $legacySkillFile = Join-Path $legacySkill "SKILL.md"
    $legacySol = Join-Path $TestHome ".codex/agents/sol-planner.toml"

    [System.IO.File]::AppendAllText($legacySkillFile, "`nuser modification`n")
    [System.IO.File]::AppendAllText($legacySol, "`nuser modification`n")
    $before = Get-ContractSnapshot $TestHome

    Assert-LifecycleFails -Path $Install -TestHome $TestHome -ExpectedError "(?i)modified" -Message "modified v0.1 targets were accepted"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $TestHome) "modified v0.1 refusal changed the home"
    Assert-UserMarkersPreserved $TestHome $markers
}

function Test-FilesystemRootRefusal {
    $filesystemRoot = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($TestRoot))
    $before = Get-ContractSnapshot $filesystemRoot

    Assert-LifecycleFails -Path $Install -TestHome $filesystemRoot -ExpectedError "filesystem root" -Message "install accepted the filesystem root"
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
        if ($exitCode -ne 0 -or -not (Test-Path -LiteralPath $Link)) {
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
    if (Test-Path -LiteralPath $Path) {
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
        Assert-LifecycleFails -Path $Install -TestHome $link -ExpectedError "(?i)(unsafe install directory|reparse point)" -Message "install accepted an ORCHESTRATE_HOME reparse point"
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
    $TestHome = Join-Path $TestRoot "fresh home with spaces"
    $markers = Seed-UserFiles $TestHome

    Invoke-Install $TestHome
    Assert-Installed $TestHome
    Assert-UserMarkersPreserved $TestHome $markers
    Invoke-Validate $TestHome
    Invoke-Install $TestHome
    Assert-Installed $TestHome
    Assert-UserMarkersPreserved $TestHome $markers
    Invoke-Uninstall $TestHome
    Assert-Uninstalled $TestHome
    Assert-UserMarkersPreserved $TestHome $markers
    Invoke-Install $TestHome
    Assert-Installed $TestHome
    Invoke-Uninstall $TestHome -RestoreLatest
    Assert-Uninstalled $TestHome
    Assert-UserMarkersPreserved $TestHome $markers
}

function Test-RepeatInstallRestoreLatestKeepsV050Ownership {
    $TestHome = Join-Path $TestRoot "repeat v0.5 restore home"
    $markers = Seed-UserFiles $TestHome
    Invoke-Install $TestHome
    $beforeSecondInstall = Get-PathFingerprint $TestHome

    Invoke-Install $TestHome
    Invoke-Uninstall $TestHome -RestoreLatest

    Assert-Equal $beforeSecondInstall (Get-PathFingerprint $TestHome) "RestoreLatest did not restore the prior v0.5 ownership state"
    Assert-Equal 0 (Invoke-CheckProcess -Path $Install -TestHome $TestHome) "restored v0.5 ownership state is not manageable"
    Assert-UserMarkersPreserved $TestHome $markers
}

function Test-V040UpgradeRemovesAliasAndRestoresExactly {
    $TestHome = Join-Path $TestRoot "v0.4 alias migration home"
    $markers = Seed-UserFiles $TestHome
    Seed-V040Install $TestHome
    $compatSkill = Join-Path $TestHome ".agents/skills/sol-luna"
    $state = Join-Path $TestHome ".codex/sol-control/install-state"
    $oldCompat = Get-PathFingerprint $compatSkill
    $oldState = Get-FileDigest $state
    $before = Get-ContractSnapshot $TestHome

    Assert-Equal 2 (Invoke-CheckProcess -Path $Install -TestHome $TestHome) "v0.4 check did not require the v0.5 migration"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $TestHome) "v0.4 check changed the installation"

    Invoke-Install $TestHome
    Assert-Installed $TestHome
    Assert-UserMarkersPreserved $TestHome $markers

    Invoke-Uninstall $TestHome -RestoreLatest
    Assert-PathExists $compatSkill
    Assert-Equal $oldCompat (Get-PathFingerprint $compatSkill) "RestoreLatest did not restore the v0.4 compatibility skill"
    Assert-Equal $oldState (Get-FileDigest $state) "RestoreLatest did not restore the v0.4 ownership state"
    $restored = Get-Content -LiteralPath $state -Raw
    Assert-True ($restored -match "(?m)^version=3\s*$") "restored ownership state is not v0.4"
    Assert-True ($restored -match "(?m)^compat_skill_sha256=[0-9a-f]{64}\s*$") "restored v0.4 ownership state lost the compatibility checksum"
    Assert-Equal 2 (Invoke-CheckProcess -Path $Install -TestHome $TestHome) "restored v0.4 state should require migration again"
    Assert-UserMarkersPreserved $TestHome $markers
}

function Test-V030Upgrade {
    $TestHome = Join-Path $TestRoot "v0.3 upgrade home"
    $markers = Seed-UserFiles $TestHome
    Seed-V030Install $TestHome

    # A legacy v0.3 state may predate the Terra target and checksum.  Check
    # must remain read-only (and report that an update is required), while a
    # normal install is allowed to add the newly introduced owned target.
    $terra = Join-Path $TestHome ".codex/agents/terra-high-worker.toml"
    Assert-PathExists $terra
    Remove-Item -LiteralPath $terra -Force
    $state = Join-Path $TestHome ".codex/sol-luna/install-state"
    $withoutTerra = @((Get-Content -LiteralPath $state) | Where-Object { $_ -notmatch "^terra_sha256=" })
    Write-TestText $state (($withoutTerra -join "`n") + "`n")
    Assert-PathAbsent $terra
    $legacyState = Get-Content -LiteralPath $state -Raw
    Assert-True ($legacyState -notmatch "(?m)^terra_sha256=") "legacy v0.3 state unexpectedly has a Terra checksum"
    $before = Get-ContractSnapshot $TestHome

    $checkExit = Invoke-CheckProcess -Path $Install -TestHome $TestHome
    Assert-Equal 2 $checkExit "legacy v0.3 check did not report an update"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $TestHome) "legacy v0.3 check changed the installation"

    Invoke-Install $TestHome
    Assert-Installed $TestHome
    Assert-UserMarkersPreserved $TestHome $markers
}

function Test-V01MigrationAndRestoreLatest {
    $TestHome = Join-Path $TestRoot "v0.1 migration home"
    $markers = Seed-UserFiles $TestHome
    Seed-V01Install $TestHome
    $legacySkill = Join-Path $TestHome ".agents/skills/orchestrate-sol-luna"
    $legacySol = Join-Path $TestHome ".codex/agents/sol-planner.toml"
    $legacyLuna = Join-Path $TestHome ".codex/agents/luna-max-worker.toml"
    $oldSkill = Get-PathFingerprint $legacySkill
    $oldSol = Get-PathFingerprint $legacySol
    $oldLuna = Get-PathFingerprint $legacyLuna

    Invoke-Install $TestHome
    Assert-Installed $TestHome
    Assert-PathAbsent $legacySkill
    Assert-PathAbsent $legacySol
    Assert-UserMarkersPreserved $TestHome $markers

    Invoke-Uninstall $TestHome -RestoreLatest
    Assert-Uninstalled $TestHome -ExpectSharedLuna
    Assert-Equal $oldSkill (Get-PathFingerprint $legacySkill) "v0.1 skill was not restored"
    Assert-Equal $oldSol (Get-PathFingerprint $legacySol) "v0.1 Sol agent was not restored"
    Assert-Equal $oldLuna (Get-PathFingerprint $legacyLuna) "shared Luna was not restored"
    Assert-UserMarkersPreserved $TestHome $markers
}

function Test-StateOnlyV01StateConvergence {
    $TestHome = Join-Path $TestRoot "state-only v0.1 convergence home"
    $markers = Seed-UserFiles $TestHome
    Seed-V01Install $TestHome
    $legacySkill = Join-Path $TestHome ".agents/skills/orchestrate-sol-luna"
    $legacySol = Join-Path $TestHome ".codex/agents/sol-planner.toml"
    $legacyState = Join-Path $TestHome ".codex/orchestrate-sol-luna/install-state"
    $legacyStateDigest = Get-FileDigest $legacyState
    Remove-Item -LiteralPath $legacySkill -Recurse -Force
    Remove-Item -LiteralPath $legacySol -Force

    Invoke-Install $TestHome
    Assert-Installed $TestHome
    Assert-PathAbsent $legacyState
    $state = Join-Path $TestHome ".codex/sol-control/install-state"
    $backupId = ((Get-Content -LiteralPath $state) | Where-Object { $_ -match "^backup_id=" }) -replace "^backup_id=", ""
    $backupState = Join-Path $TestHome (".codex/sol-control/backups/{0}/legacy/install-state" -f $backupId)
    Assert-PathExists $backupState
    Assert-Equal $legacyStateDigest (Get-FileDigest $backupState) "legacy state backup was not byte-for-byte identical"
    $manifest = Get-Content -LiteralPath (Join-Path $TestHome (".codex/sol-control/backups/{0}/manifest" -f $backupId)) -Raw
    Assert-True ($manifest -match "(?m)^legacy_state_presence=present\s*$") "manifest did not record legacy state presence"
    Assert-True ($manifest -match ("(?m)^legacy_state_sha256={0}\s*$" -f $legacyStateDigest)) "manifest did not record legacy state checksum"
    Assert-Equal 0 (Invoke-CheckProcess -Path $Install -TestHome $TestHome) "state-only migration did not converge check mode"

    Invoke-Uninstall $TestHome -RestoreLatest
    Assert-Equal $legacyStateDigest (Get-FileDigest $legacyState) "RestoreLatest did not restore the exact legacy install state"
    Assert-UserMarkersPreserved $TestHome $markers
}

function Test-StateOnlyV01PlainUninstallDoesNotRestore {
    $TestHome = Join-Path $TestRoot "state-only v0.1 plain uninstall home"
    Seed-V01Install $TestHome
    Remove-Item -LiteralPath (Join-Path $TestHome ".agents/skills/orchestrate-sol-luna") -Recurse -Force
    Remove-Item -LiteralPath (Join-Path $TestHome ".codex/agents/sol-planner.toml") -Force
    $legacyState = Join-Path $TestHome ".codex/orchestrate-sol-luna/install-state"

    Invoke-Install $TestHome
    Assert-PathAbsent $legacyState
    Invoke-Uninstall $TestHome
    Assert-PathAbsent $legacyState
}

function Test-StateOnlyV01RestoreRefusesExistingState {
    $TestHome = Join-Path $TestRoot "state-only v0.1 restore conflict home"
    Seed-V01Install $TestHome
    Remove-Item -LiteralPath (Join-Path $TestHome ".agents/skills/orchestrate-sol-luna") -Recurse -Force
    Remove-Item -LiteralPath (Join-Path $TestHome ".codex/agents/sol-planner.toml") -Force
    Invoke-Install $TestHome
    $legacyState = Join-Path $TestHome ".codex/orchestrate-sol-luna/install-state"
    Write-TestText $legacyState "user-owned legacy state`n"
    $before = Get-ContractSnapshot $TestHome

    Assert-LifecycleFails -Path $Uninstall -TestHome $TestHome -Parameters @{ RestoreLatest = $true } -ExpectedError "(?i)legacy install state already exists" -Message "RestoreLatest overwrote an existing legacy state"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $TestHome) "RestoreLatest conflict changed the home"
}

function Test-OldManifestWithoutLegacyStateFields {
    $TestHome = Join-Path $TestRoot "old manifest without legacy state fields"
    Invoke-Install $TestHome
    $state = Join-Path $TestHome ".codex/sol-control/install-state"
    $backupId = ((Get-Content -LiteralPath $state) | Where-Object { $_ -match "^backup_id=" }) -replace "^backup_id=", ""
    $manifest = Join-Path $TestHome (".codex/sol-control/backups/{0}/manifest" -f $backupId)
    $withoutLegacyState = @((Get-Content -LiteralPath $manifest) | Where-Object { $_ -notmatch "^legacy_state_" })
    Write-TestText $manifest (($withoutLegacyState -join "`n") + "`n")

    Invoke-Uninstall $TestHome
    Assert-Uninstalled $TestHome
}

function Test-LegacyStateManifestMalformedRefusal {
    foreach ($kind in @("partial", "empty-pair")) {
        $TestHome = Join-Path $TestRoot ("legacy state manifest " + $kind)
        Seed-V01Install $TestHome
        Remove-Item -LiteralPath (Join-Path $TestHome ".agents/skills/orchestrate-sol-luna") -Recurse -Force
        Remove-Item -LiteralPath (Join-Path $TestHome ".codex/agents/sol-planner.toml") -Force
        Invoke-Install $TestHome
        $state = Join-Path $TestHome ".codex/sol-control/install-state"
        $backupId = ((Get-Content -LiteralPath $state) | Where-Object { $_ -match "^backup_id=" }) -replace "^backup_id=", ""
        $manifest = Join-Path $TestHome (".codex/sol-control/backups/{0}/manifest" -f $backupId)
        $lines = @(Get-Content -LiteralPath $manifest)
        if ($kind -eq "partial") {
            $lines = @($lines | ForEach-Object {
                if ($_ -match "^legacy_state_presence=") { "legacy_state_presence=" }
                else { $_ }
            } | Where-Object { $_ -notmatch "^legacy_state_sha256=" })
        }
        else {
            $lines = @($lines | ForEach-Object {
                if ($_ -match "^legacy_state_presence=") { "legacy_state_presence=" }
                elseif ($_ -match "^legacy_state_sha256=") { "legacy_state_sha256=" }
                else { $_ }
            })
        }
        Write-TestText $manifest (($lines -join "`n") + "`n")
        $before = Get-ContractSnapshot $TestHome

        Assert-LifecycleFails -Path $Uninstall -TestHome $TestHome -Parameters @{ RestoreLatest = $true } -ExpectedError "(?i)(incomplete|presence|checksum)" -Message ("malformed legacy state manifest was accepted: " + $kind)
        Assert-SnapshotEqual $before (Get-ContractSnapshot $TestHome) ("malformed legacy state manifest changed the home: " + $kind)
    }
}

function Test-StateOnlyV01Rollback {
    foreach ($failpoint in @("after-replace", "after-state")) {
        $TestHome = Join-Path $TestRoot ("state-only v0.1 rollback " + $failpoint)
        Seed-V01Install $TestHome
        Remove-Item -LiteralPath (Join-Path $TestHome ".agents/skills/orchestrate-sol-luna") -Recurse -Force
        Remove-Item -LiteralPath (Join-Path $TestHome ".codex/agents/sol-planner.toml") -Force
        $before = Get-ContractSnapshot $TestHome

        Assert-LifecycleFails -Path $Install -TestHome $TestHome -Failpoint $failpoint -Message ("state-only v0.1 " + $failpoint + " did not fail")
        Assert-SnapshotEqual $before (Get-ContractSnapshot $TestHome) ("state-only v0.1 " + $failpoint + " rollback changed the home")
    }
}

function Test-TerraBackupRestoreLatest {
    $TestHome = Join-Path $TestRoot "Terra backup restore home"
    $markers = Seed-UserFiles $TestHome
    Seed-V030Install $TestHome
    $skill = Join-Path $TestHome ".agents/skills/sol-luna"
    $sol = Join-Path $TestHome ".codex/agents/sol-controller.toml"
    $luna = Join-Path $TestHome ".codex/agents/luna-max-worker.toml"
    $terra = Join-Path $TestHome ".codex/agents/terra-high-worker.toml"
    Write-TestText $terra "name = 'previous-terra'`nmodel = 'previous-model'`n"
    $oldSkill = Get-PathFingerprint $skill
    $oldSol = Get-PathFingerprint $sol
    $oldLuna = Get-PathFingerprint $luna
    $oldTerraFingerprint = Get-PathFingerprint $terra
    $oldTerra = Get-FileDigest $terra
    $previousState = Join-Path $TestHome ".codex/sol-luna/install-state"
    $stateLines = @((Get-Content -LiteralPath $previousState) | ForEach-Object {
        if ($_ -match "^terra_sha256=") {
            "terra_sha256=$oldTerra"
        }
        else {
            $_
        }
    })
    Write-TestText $previousState (($stateLines -join "`n") + "`n")
    Assert-True ((Get-Content -LiteralPath $previousState -Raw) -match "(?m)^terra_sha256=$oldTerra\s*$") "seeded Terra ownership state does not match the existing target"

    Invoke-Install $TestHome
    Assert-Installed $TestHome
    Assert-True ($oldTerra -ne (Get-FileDigest $terra)) "owned Terra target was not replaced by v0.5 install"

    $state = Join-Path $TestHome ".codex/sol-control/install-state"
    $stateText = Get-Content -LiteralPath $state -Raw
    Assert-True ($stateText -match "(?m)^terra_sha256=[0-9a-f]{64}\s*$") "Terra install state checksum is missing"
    $backupId = ((Get-Content -LiteralPath $state) | Where-Object { $_ -match "^backup_id=" }) -replace "^backup_id=", ""
    Assert-True (-not [string]::IsNullOrWhiteSpace($backupId)) "Terra backup id is missing"
    $manifest = Join-Path $TestHome (".codex/sol-control/backups/{0}/manifest" -f $backupId)
    Assert-PathExists $manifest
    $manifestText = Get-Content -LiteralPath $manifest -Raw
    Assert-True ($manifestText -match "(?m)^v040_terra_presence=present\s*$") "Terra backup manifest did not record a present target"

    Invoke-Uninstall $TestHome -RestoreLatest
    Assert-PathAbsent $state
    Assert-PathExists $skill
    Assert-PathExists $sol
    Assert-PathExists $luna
    Assert-PathExists $terra
    Assert-Equal $oldSkill (Get-PathFingerprint $skill) "-RestoreLatest did not restore the original v0.3 skill"
    Assert-Equal $oldSol (Get-PathFingerprint $sol) "-RestoreLatest did not restore the original v0.3 Sol target"
    Assert-Equal $oldLuna (Get-PathFingerprint $luna) "-RestoreLatest did not restore the original v0.3 Luna target"
    Assert-PathExists $previousState
    Assert-Equal $oldTerraFingerprint (Get-PathFingerprint $terra) "-RestoreLatest did not restore the original Terra target"
    Assert-Equal $oldTerra (Get-FileDigest $terra) "-RestoreLatest did not restore the original Terra target"
    Assert-UserMarkersPreserved $TestHome $markers
}

function Test-TerraOwnershipStateRefusal {
    $TestHome = Join-Path $TestRoot "terra no ownership state home"
    $markers = Seed-UserFiles $TestHome
    $terra = Join-Path $TestHome ".codex/agents/terra-high-worker.toml"
    Write-TestText $terra "name = 'user-owned-terra'`n"
    $before = Get-ContractSnapshot $TestHome

    $checkExit = Invoke-CheckProcess -Path $Install -TestHome $TestHome
    Assert-True ($checkExit -ne 0) "check accepted Terra without ownership state"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $TestHome) "check changed Terra without ownership state"
    Assert-LifecycleFails -Path $Install -TestHome $TestHome -ExpectedError "(?i)Terra.*ownership state" -Message "install accepted Terra without ownership state"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $TestHome) "install changed Terra without ownership state"
    Assert-UserMarkersPreserved $TestHome $markers

    $TestHome = Join-Path $TestRoot "terra missing checksum state home"
    $markers = Seed-UserFiles $TestHome
    Invoke-Install $TestHome
    $state = Join-Path $TestHome ".codex/sol-control/install-state"
    $withoutTerra = @((Get-Content -LiteralPath $state) | Where-Object { $_ -notmatch "^terra_sha256=" })
    Write-TestText $state (($withoutTerra -join "`n") + "`n")
    $before = Get-ContractSnapshot $TestHome

    $checkExit = Invoke-CheckProcess -Path $Install -TestHome $TestHome
    Assert-True ($checkExit -ne 0) "check accepted a v0.3 Terra target without a checksum"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $TestHome) "check changed missing-Terra-checksum state"
    Assert-LifecycleFails -Path $Install -TestHome $TestHome -ExpectedError "(?i)Terra.*checksum" -Message "install accepted a v0.3 Terra target without a checksum"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $TestHome) "install changed missing-Terra-checksum state"
    Assert-UserMarkersPreserved $TestHome $markers
}

function Test-ModifiedCurrentTargetRefusal {
    $TestHome = Join-Path $TestRoot "modified target home"
    $markers = Seed-UserFiles $TestHome
    Invoke-Install $TestHome
    $modified = Join-Path $TestHome ".codex/agents/sol-controller.toml"
    [System.IO.File]::AppendAllText($modified, "`nuser modification`n")
    $before = Get-ContractSnapshot $TestHome

    Assert-LifecycleFails -Path $Uninstall -TestHome $TestHome -Message "checksum-mismatched current target was removed"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $TestHome) "modified-target refusal changed the home"
    Assert-UserMarkersPreserved $TestHome $markers
}

function Test-ModifiedTerraTargetRefusal {
    $TestHome = Join-Path $TestRoot "modified Terra target home"
    $markers = Seed-UserFiles $TestHome
    Invoke-Install $TestHome
    $modified = Join-Path $TestHome ".codex/agents/terra-high-worker.toml"
    [System.IO.File]::AppendAllText($modified, "`nuser modification`n")
    $before = Get-ContractSnapshot $TestHome

    Assert-LifecycleFails -Path $Uninstall -TestHome $TestHome -ExpectedError "(?i)Terra" -Message "checksum-mismatched Terra target was removed"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $TestHome) "modified Terra target refusal changed the home"
    Assert-UserMarkersPreserved $TestHome $markers
}

function Test-RollbackFailpoint {
    $TestHome = Join-Path $TestRoot "rollback failpoint home"
    $markers = Seed-UserFiles $TestHome
    $before = Get-ContractSnapshot $TestHome

    Assert-LifecycleFails -Path $Install -TestHome $TestHome -Failpoint "after-replace" -Message "after-replace failpoint did not fail"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $TestHome) "rollback did not restore the isolated home"
    Assert-UserMarkersPreserved $TestHome $markers
}

function Test-UninstallTransactionCleanupFailpoint {
    $TestHome = Join-Path $TestRoot "uninstall transaction cleanup failpoint home"
    $markers = Seed-UserFiles $TestHome
    Invoke-Install $TestHome
    $before = Get-ContractSnapshot $TestHome
    $backupRoot = Join-Path $TestHome ".codex/sol-control/backups"
    $backupBefore = Get-PathFingerprint $backupRoot

    Assert-LifecycleFails -Path $Uninstall -TestHome $TestHome -Failpoint "before-transaction-cleanup" -ExpectedError "(?i)before transaction cleanup" -Message "uninstall cleanup failpoint did not fail"
    Assert-SnapshotEqual $before (Get-ContractSnapshot $TestHome) "uninstall cleanup failpoint did not roll back the isolated home"
    Assert-Equal $backupBefore (Get-PathFingerprint $backupRoot) "uninstall cleanup failpoint removed or changed the recovery backup"
    Assert-UserMarkersPreserved $TestHome $markers
}

function Test-CheckModeReadOnly {
    $TestHome = Join-Path $TestRoot "check mode home"
    $before = Get-PathFingerprint $TestHome
    $checkExit = Invoke-CheckProcess -Path $Install -TestHome $TestHome
    Assert-Equal 2 $checkExit "fresh check mode did not return exit code 2"
    Assert-Equal $before (Get-PathFingerprint $TestHome) "fresh check mode wrote to the home"
    Assert-PathAbsent $TestHome

    Invoke-Install $TestHome
    $before = Get-PathFingerprint $TestHome
    $checkExit = Invoke-CheckProcess -Path $Install -TestHome $TestHome
    Assert-Equal 0 $checkExit "consistent check mode did not return exit code 0"
    Assert-Equal $before (Get-PathFingerprint $TestHome) "consistent check mode changed the home"
}

function Test-IsolatedHomes {
    $TestHomeA = Join-Path $TestRoot "isolated home A"
    $TestHomeB = Join-Path $TestRoot "isolated home B"
    $markersA = Seed-UserFiles $TestHomeA
    $markersB = Seed-UserFiles $TestHomeB

    Invoke-Install $TestHomeA
    Assert-Installed $TestHomeA
    Assert-PathAbsent (Join-Path $TestHomeB ".codex/sol-control/install-state")
    Invoke-Install $TestHomeB
    Assert-Installed $TestHomeB
    Assert-UserMarkersPreserved $TestHomeA $markersA
    Assert-UserMarkersPreserved $TestHomeB $markersB

    Invoke-Uninstall $TestHomeA
    Assert-Uninstalled $TestHomeA
    Assert-Installed $TestHomeB
    Invoke-Validate $TestHomeB
    Invoke-Uninstall $TestHomeB
    Assert-Uninstalled $TestHomeB
}

try {
    [System.IO.Directory]::CreateDirectory($TestRoot) | Out-Null

    foreach ($required in @($Install, $Validate, $Uninstall)) {
        Assert-PathExists $required
    }

    Test-FreshRepeatInstallAndSpaces
    Test-RepeatInstallRestoreLatestKeepsV050Ownership
    Test-V040UpgradeRemovesAliasAndRestoresExactly
    Test-V030Upgrade
    Test-V01MigrationAndRestoreLatest
    Test-StateOnlyV01StateConvergence
    Test-StateOnlyV01PlainUninstallDoesNotRestore
    Test-StateOnlyV01RestoreRefusesExistingState
    Test-OldManifestWithoutLegacyStateFields
    Test-LegacyStateManifestMalformedRefusal
    Test-StateOnlyV01Rollback
    Test-TerraBackupRestoreLatest
    Test-TerraOwnershipStateRefusal
    Test-ModifiedV01MigrationFailsClosed
    Test-ModifiedCurrentTargetRefusal
    Test-ModifiedTerraTargetRefusal
    Test-RollbackFailpoint
    Test-UninstallTransactionCleanupFailpoint
    Test-CheckModeReadOnly
    Test-IsolatedHomes
    Test-FilesystemRootRefusal
    Test-ReparsePointRefusal

    Write-Output "Windows lifecycle contract: PASS"
}
finally {
    if (Test-Path -LiteralPath $TestRoot) {
        Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
