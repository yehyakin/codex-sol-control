#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$installScript = Join-Path $repoRoot "scripts/install.ps1"
$validateScript = Join-Path $repoRoot "scripts/validate.ps1"
$uninstallScript = Join-Path $repoRoot "scripts/uninstall.ps1"
$engine = (Get-Process -Id $PID).Path
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-prove-v100-windows-" + [Guid]::NewGuid().ToString("N"))
[System.IO.Directory]::CreateDirectory($testRoot) | Out-Null

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function Assert-PathExists {
    param([Parameter(Mandatory = $true)][string]$Path)
    Assert-True (Test-Path -LiteralPath $Path) "expected path is missing: $Path"
}

function Assert-PathAbsent {
    param([Parameter(Mandatory = $true)][string]$Path)
    Assert-True (-not (Test-Path -LiteralPath $Path)) "unexpected path exists: $Path"
}

function Write-TestText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { [System.IO.Directory]::CreateDirectory($parent) | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-FileDigest {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-BytesDigest {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-TreeDigest {
    param([Parameter(Mandatory = $true)][string]$Path)
    $entries = New-Object System.Collections.Generic.List[string]
    foreach ($item in @(Get-ChildItem -LiteralPath $Path -Force -Recurse | Sort-Object -Property FullName)) {
        $relative = $item.FullName.Substring($Path.Length).TrimStart([char[]]"/\").Replace("\", "/")
        if ($item.PSIsContainer) { $entries.Add("D`t$relative`n") }
        else { $entries.Add("F`t$relative`t$(Get-FileDigest $item.FullName)`n") }
    }
    return Get-BytesDigest ([System.Text.Encoding]::UTF8.GetBytes(($entries -join "")))
}

function Invoke-LifecycleScript {
    param(
        [Parameter(Mandatory = $true)][string]$Script,
        [string[]]$Arguments = @(),
        [int]$ExpectedExitCode = 0
    )
    & $engine -NoLogo -NoProfile -NonInteractive -File $Script @Arguments *> $null
    $actual = $LASTEXITCODE
    if ($actual -ne $ExpectedExitCode) {
        throw "unexpected exit code for $Script: expected $ExpectedExitCode, got $actual"
    }
}

function Invoke-CheckProcess {
    param(
        [Parameter(Mandatory = $true)][string]$HomePath,
        [int]$ExpectedExitCode = 0
    )
    $oldHome = $env:ORCHESTRATE_HOME
    try {
        $env:ORCHESTRATE_HOME = $HomePath
        Invoke-LifecycleScript $installScript @("-Check") $ExpectedExitCode
    }
    finally {
        $env:ORCHESTRATE_HOME = $oldHome
    }
}

function Test-CheckModeReadOnly {
    $homePath = Join-Path $testRoot "check-only-home"
    Assert-PathAbsent $homePath
    Invoke-CheckProcess $homePath
    Assert-PathAbsent $homePath
}

function Test-CheckRejectsUnsafeParent {
    $homePath = Join-Path $testRoot "unsafe-check-parent"
    [System.IO.Directory]::CreateDirectory($homePath) | Out-Null
    Write-TestText (Join-Path $homePath ".agents") "user file`n"
    $before = Get-FileDigest (Join-Path $homePath ".agents")
    Invoke-CheckProcess $homePath 1
    Assert-True ((Get-FileDigest (Join-Path $homePath ".agents")) -eq $before) "check changed unsafe parent"
    Assert-PathAbsent (Join-Path $homePath ".codex")
}

function Install-At {
    param(
        [Parameter(Mandatory = $true)][string]$HomePath,
        [int]$ExpectedExitCode = 0,
        [string]$Failpoint = ""
    )
    $oldHome = $env:ORCHESTRATE_HOME
    $oldFailpoint = $env:ORCHESTRATE_FAILPOINT
    try {
        $env:ORCHESTRATE_HOME = $HomePath
        $env:ORCHESTRATE_FAILPOINT = $Failpoint
        Invoke-LifecycleScript $installScript @() $ExpectedExitCode
    }
    finally {
        $env:ORCHESTRATE_HOME = $oldHome
        $env:ORCHESTRATE_FAILPOINT = $oldFailpoint
    }
}

function Uninstall-At {
    param(
        [Parameter(Mandatory = $true)][string]$HomePath,
        [switch]$RestoreLatest,
        [int]$ExpectedExitCode = 0
    )
    $oldHome = $env:ORCHESTRATE_HOME
    try {
        $env:ORCHESTRATE_HOME = $HomePath
        $arguments = @()
        if ($RestoreLatest) { $arguments = @("-RestoreLatest") }
        Invoke-LifecycleScript $uninstallScript $arguments $ExpectedExitCode
    }
    finally {
        $env:ORCHESTRATE_HOME = $oldHome
    }
}

function Assert-V1Installed {
    param([Parameter(Mandatory = $true)][string]$HomePath)
    foreach ($relative in @(
        ".agents/skills/codex-prove/SKILL.md",
        ".agents/skills/sol-control/SKILL.md",
        ".codex/agents/prove-controller.toml",
        ".codex/agents/prove-complex-worker.toml",
        ".codex/agents/prove-efficient-worker.toml",
        ".codex/codex-prove/install-state"
    )) { Assert-PathExists (Join-Path $HomePath $relative) }
    foreach ($relative in @(
        ".codex/agents/sol-controller.toml",
        ".codex/agents/terra-high-worker.toml",
        ".codex/agents/luna-max-worker.toml"
    )) { Assert-PathAbsent (Join-Path $HomePath $relative) }
    $state = Get-Content -LiteralPath (Join-Path $HomePath ".codex/codex-prove/install-state") -Raw
    Assert-True ($state -match '(?m)^version=5$') "v1 state version is invalid"
}

function Test-FreshLifecycle {
    $homePath = Join-Path $testRoot "fresh"
    [System.IO.Directory]::CreateDirectory($homePath) | Out-Null
    Write-TestText (Join-Path $homePath ".codex/config.toml") "# preserve me`n"
    Write-TestText (Join-Path $homePath ".codex/agents/other-agent.toml") "name = `"other-agent`"`n"
    $configBefore = Get-FileDigest (Join-Path $homePath ".codex/config.toml")
    $otherBefore = Get-FileDigest (Join-Path $homePath ".codex/agents/other-agent.toml")

    Install-At $homePath
    Assert-V1Installed $homePath
    Assert-True ((Get-FileDigest (Join-Path $homePath ".codex/config.toml")) -eq $configBefore) "config.toml changed"
    Assert-True ((Get-FileDigest (Join-Path $homePath ".codex/agents/other-agent.toml")) -eq $otherBefore) "unrelated agent changed"

    Install-At $homePath
    Assert-V1Installed $homePath
    Uninstall-At $homePath
    foreach ($relative in @(
        ".agents/skills/codex-prove",
        ".agents/skills/sol-control",
        ".codex/agents/prove-controller.toml",
        ".codex/agents/prove-complex-worker.toml",
        ".codex/agents/prove-efficient-worker.toml",
        ".codex/codex-prove/install-state"
    )) { Assert-PathAbsent (Join-Path $homePath $relative) }
    Assert-True ((Get-FileDigest (Join-Path $homePath ".codex/config.toml")) -eq $configBefore) "config.toml changed during uninstall"
    Assert-True ((Get-FileDigest (Join-Path $homePath ".codex/agents/other-agent.toml")) -eq $otherBefore) "unrelated agent changed during uninstall"
}

function Test-ModifiedTargetRefusal {
    $homePath = Join-Path $testRoot "modified"
    [System.IO.Directory]::CreateDirectory($homePath) | Out-Null
    Install-At $homePath
    Add-Content -LiteralPath (Join-Path $homePath ".agents/skills/codex-prove/SKILL.md") -Value "user change"
    Install-At $homePath 1
    Assert-PathExists (Join-Path $homePath ".agents/skills/codex-prove/SKILL.md")
}

function Test-InstallRollback {
    $homePath = Join-Path $testRoot "rollback"
    [System.IO.Directory]::CreateDirectory($homePath) | Out-Null
    Install-At $homePath
    $before = Get-FileDigest (Join-Path $homePath ".codex/agents/prove-controller.toml")
    Install-At $homePath 1 "after-replace"
    Assert-True ((Get-FileDigest (Join-Path $homePath ".codex/agents/prove-controller.toml")) -eq $before) "rollback did not restore controller"
    Assert-V1Installed $homePath
}

function Test-V050MigrationAndRestore {
    $homePath = Join-Path $testRoot "v050"
    [System.IO.Directory]::CreateDirectory($homePath) | Out-Null
    $oldSkill = Join-Path $homePath ".agents/skills/sol-control"
    Write-TestText (Join-Path $oldSkill "SKILL.md") "---`nname: sol-control`ndescription: old managed skill`n---`nold`n"
    Write-TestText (Join-Path $oldSkill "agents/openai.yaml") "interface:`n  default_prompt: old`n"
    $oldController = Join-Path $homePath ".codex/agents/sol-controller.toml"
    $oldComplex = Join-Path $homePath ".codex/agents/terra-high-worker.toml"
    $oldEfficient = Join-Path $homePath ".codex/agents/luna-max-worker.toml"
    Write-TestText $oldController "name = `"sol-controller`"`n"
    Write-TestText $oldComplex "name = `"terra-high-worker`"`n"
    Write-TestText $oldEfficient "name = `"luna-max-worker`"`n"
    $oldState = Join-Path $homePath ".codex/sol-control/install-state"
    $stateText = @(
        "version=4",
        "backup_id=old-v050",
        "skill_sha256=$(Get-TreeDigest $oldSkill)",
        "sol_sha256=$(Get-FileDigest $oldController)",
        "luna_sha256=$(Get-FileDigest $oldEfficient)",
        "terra_sha256=$(Get-FileDigest $oldComplex)"
    ) -join "`n"
    Write-TestText $oldState ($stateText + "`n")
    $oldSkillHash = Get-TreeDigest $oldSkill

    Install-At $homePath
    Assert-V1Installed $homePath
    Uninstall-At $homePath -RestoreLatest

    Assert-PathAbsent (Join-Path $homePath ".agents/skills/codex-prove")
    Assert-PathAbsent (Join-Path $homePath ".codex/agents/prove-controller.toml")
    Assert-PathExists $oldSkill
    Assert-PathExists $oldController
    Assert-PathExists $oldComplex
    Assert-PathExists $oldEfficient
    Assert-PathExists $oldState
    Assert-True ((Get-TreeDigest $oldSkill) -eq $oldSkillHash) "restore did not recover v0.5 Skill"
}

try {
    Invoke-LifecycleScript $validateScript @() 0
    Test-CheckModeReadOnly
    Test-CheckRejectsUnsafeParent
    Test-FreshLifecycle
    Test-ModifiedTargetRefusal
    Test-InstallRollback
    Test-V050MigrationAndRestore
    Write-Output "Windows lifecycle contract: PASS"
}
finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
