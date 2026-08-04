#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Check
)

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
        # A non-empty or concurrently changed legacy root is left untouched.
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
        ".agents/skills/sol-control/SKILL.md",
        ".agents/skills/sol-control/agents/openai.yaml",
        ".agents/skills/sol-luna/SKILL.md",
        ".agents/skills/sol-luna/agents/openai.yaml",
        ".codex/agents/sol-controller.toml",
        ".codex/agents/terra-high-worker.toml",
        ".codex/agents/luna-max-worker.toml",
        "scripts/install.sh",
        "scripts/validate.sh",
        "scripts/test.sh",
        "scripts/uninstall.sh",
        "scripts/install.ps1",
        "scripts/validate.ps1",
        "scripts/uninstall.ps1",
        "README.md",
        "README.en.md",
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

    $skillRoot = Join-Path $Root ".agents/skills/sol-control"
    Assert-PlainTree $skillRoot
    $runtimeDirect = Join-Path $skillRoot "runtime-notes.md"
    $runtimeReference = Join-Path $skillRoot "references/runtime-notes.md"
    if (-not (Test-Path -LiteralPath $runtimeDirect -PathType Leaf) -and
        -not (Test-Path -LiteralPath $runtimeReference -PathType Leaf)) {
        throw "source validation failed"
    }

    $skill = Get-Content -LiteralPath (Join-Path $skillRoot "SKILL.md") -Raw
    if ($skill -notmatch "(?m)^---\r?$" -or
        $skill -notmatch "(?m)^name:\s*sol-control\s*$" -or
        $skill -notmatch "(?m)^description:\s*Use when\b" -or
        $skill -notmatch '\$sol-control') {
        throw "source validation failed"
    }

    $openai = Get-Content -LiteralPath (Join-Path $skillRoot "agents/openai.yaml") -Raw
    foreach ($marker in @("interface:", "display_name:", "short_description:", "default_prompt:")) {
        if ($openai.IndexOf($marker, [System.StringComparison]::Ordinal) -lt 0) {
            throw "source validation failed"
        }
    }
    if ($openai -notmatch '\$sol-control' -or $openai -notmatch '(?m)^\s*allow_implicit_invocation:\s*false\s*$') {
        throw "source validation failed"
    }

    $compatSkillRoot = Join-Path $Root ".agents/skills/sol-luna"
    Assert-PlainTree $compatSkillRoot
    $compatSkill = Get-Content -LiteralPath (Join-Path $compatSkillRoot "SKILL.md") -Raw
    if ($compatSkill -notmatch "(?m)^name:\s*sol-luna\s*$" -or
        $compatSkill -notmatch '\$sol-luna' -or
        $compatSkill -notmatch '\$sol-control' -or
        $compatSkill -notmatch 'v0\.5\.0' -or
        @($compatSkill -split "`r?`n").Count -gt 45) {
        throw "source validation failed"
    }
    $compatOpenai = Get-Content -LiteralPath (Join-Path $compatSkillRoot "agents/openai.yaml") -Raw
    if ($compatOpenai -notmatch '\$sol-luna' -or
        $compatOpenai -notmatch '\$sol-control' -or
        $compatOpenai -notmatch '(?m)^\s*allow_implicit_invocation:\s*false\s*$') {
        throw "source validation failed"
    }

    $sol = Get-Content -LiteralPath (Join-Path $Root ".codex/agents/sol-controller.toml") -Raw
    $luna = Get-Content -LiteralPath (Join-Path $Root ".codex/agents/luna-max-worker.toml") -Raw
    $terra = Get-Content -LiteralPath (Join-Path $Root ".codex/agents/terra-high-worker.toml") -Raw
    foreach ($pair in @(
        @($sol, '(?m)^\s*name\s*=\s*"sol-controller"\s*$'),
        @($sol, '(?m)^\s*model\s*=\s*"gpt-5\.6-sol"\s*$'),
        @($sol, '(?m)^\s*model_reasoning_effort\s*=\s*"high"\s*$'),
        @($sol, '(?m)^\s*sandbox_mode\s*=\s*"read-only"\s*$'),
        @($luna, '(?m)^\s*name\s*=\s*"luna-max-worker"\s*$'),
        @($luna, '(?m)^\s*model\s*=\s*"gpt-5\.6-luna"\s*$'),
        @($luna, '(?m)^\s*model_reasoning_effort\s*=\s*"max"\s*$'),
        @($luna, '(?m)^\s*sandbox_mode\s*=\s*"workspace-write"\s*$'),
        @($luna, '(?is)do not (spawn|create).*subagent'),
        @($terra, '(?m)^\s*name\s*=\s*"terra-high-worker"\s*$'),
        @($terra, '(?m)^\s*model\s*=\s*"gpt-5\.6-terra"\s*$'),
        @($terra, '(?m)^\s*model_reasoning_effort\s*=\s*"high"\s*$'),
        @($terra, '(?m)^\s*sandbox_mode\s*=\s*"workspace-write"\s*$'),
        @($terra, '(?is)do not (spawn|create).*subagent')
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
if ($Check -and (Test-PathExists $baseDir)) {
    $baseItem = Get-Item -LiteralPath $baseDir -Force
    if (-not $baseItem.PSIsContainer -or (Test-ReparsePoint $baseItem)) {
        throw "unsafe ORCHESTRATE_HOME"
    }
}

$skillSource = Join-Path $repoRoot ".agents/skills/sol-control"
$compatSkillSource = Join-Path $repoRoot ".agents/skills/sol-luna"
$solSource = Join-Path $repoRoot ".codex/agents/sol-controller.toml"
$lunaSource = Join-Path $repoRoot ".codex/agents/luna-max-worker.toml"
$terraSource = Join-Path $repoRoot ".codex/agents/terra-high-worker.toml"

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
        $item = Get-Item -LiteralPath $directory -Force
        if (-not $item.PSIsContainer -or (Test-ReparsePoint $item)) {
            throw "unsafe install parent"
        }
    }
}

Assert-Target $newSkillTarget "Directory"
Assert-Target $compatSkillTarget "Directory"
Assert-Target $newSolTarget "File"
Assert-Target $lunaTarget "File"
Assert-Target $terraTarget "File"
Assert-Target $legacySkillTarget "Directory"
Assert-Target $legacySolTarget "File"
if (Test-PathExists $configTarget) { Assert-Target $configTarget "File" }
if (Test-PathExists $stateFile) { Assert-Target $stateFile "File" }
if (Test-PathExists $previousStateFile) { Assert-Target $previousStateFile "File" }
if (Test-PathExists $legacyStateFile) { Assert-Target $legacyStateFile "File" }

$v3StatePresent = $false
if (Test-PathExists $stateFile) {
    $v3State = Get-StateMap $stateFile
    if ((Get-StateValue $v3State "version") -ne "3") {
        throw "existing v0.4 state has an unsupported version"
    }
    $v3BackupId = Get-StateValue $v3State "backup_id"
    Assert-BackupId $v3BackupId
    $v3SkillDigest = Get-StateValue $v3State "skill_sha256"
    $v3CompatSkillDigest = Get-StateValue $v3State "compat_skill_sha256"
    $v3SolDigest = Get-StateValue $v3State "sol_sha256"
    $v3LunaDigest = Get-StateValue $v3State "luna_sha256"
    $v3TerraDigest = if ($v3State.ContainsKey("terra_sha256")) { [string]$v3State["terra_sha256"] } else { "" }
    Assert-Hash $v3SkillDigest
    Assert-Hash $v3CompatSkillDigest
    Assert-Hash $v3SolDigest
    Assert-Hash $v3LunaDigest
    if ($v3TerraDigest) { Assert-Hash $v3TerraDigest }
    if (-not (Test-Path -LiteralPath $newSkillTarget -PathType Container) -or
        -not (Test-Path -LiteralPath $compatSkillTarget -PathType Container) -or
        -not (Test-Path -LiteralPath $newSolTarget -PathType Leaf) -or
        -not (Test-Path -LiteralPath $lunaTarget -PathType Leaf)) {
        throw "existing v0.4 targets are missing"
    }
    if ((Get-TreeDigest $newSkillTarget) -ne $v3SkillDigest -or
        (Get-TreeDigest $compatSkillTarget) -ne $v3CompatSkillDigest -or
        (Get-FileDigest $newSolTarget) -ne $v3SolDigest -or
        (Get-FileDigest $lunaTarget) -ne $v3LunaDigest) {
        throw "existing v0.4 targets do not match install state"
    }
    if (Test-PathExists $terraTarget) {
        if (-not $v3TerraDigest) {
            throw "existing v0.4 Terra agent has no ownership checksum"
        }
        if ((-not (Test-Path -LiteralPath $terraTarget -PathType Leaf)) -or (Get-FileDigest $terraTarget) -ne $v3TerraDigest) {
            throw "existing v0.4 Terra agent does not match install state"
        }
    }
    elseif ($v3TerraDigest) {
        throw "existing v0.4 Terra agent does not match install state"
    }
    $v3StatePresent = $true
}
elseif (Test-PathExists $newSkillTarget) {
    throw "existing v0.4 target has no ownership state"
}

$previousStatePresent = $false
$previousSkillDigest = ""
$previousSolDigest = ""
$previousLunaDigest = ""
$previousTerraDigest = ""
if (Test-PathExists $previousStateFile) {
    $previousState = Get-StateMap $previousStateFile
    if ((Get-StateValue $previousState "version") -ne "2") {
        throw "existing Sol Luna state has an unsupported version"
    }
    $previousSkillDigest = Get-StateValue $previousState "skill_sha256"
    $previousSolDigest = Get-StateValue $previousState "sol_sha256"
    $previousLunaDigest = Get-StateValue $previousState "luna_sha256"
    $previousTerraDigest = if ($previousState.ContainsKey("terra_sha256")) { [string]$previousState["terra_sha256"] } else { "" }
    Assert-Hash $previousSkillDigest
    Assert-Hash $previousSolDigest
    Assert-Hash $previousLunaDigest
    if ($previousTerraDigest) { Assert-Hash $previousTerraDigest }
    if (-not (Test-Path -LiteralPath $compatSkillTarget -PathType Container) -or
        -not (Test-Path -LiteralPath $newSolTarget -PathType Leaf) -or
        -not (Test-Path -LiteralPath $lunaTarget -PathType Leaf)) {
        throw "existing Sol Luna targets are missing"
    }
    if ((Get-TreeDigest $compatSkillTarget) -ne $previousSkillDigest -or
        (Get-FileDigest $newSolTarget) -ne $previousSolDigest -or
        (Get-FileDigest $lunaTarget) -ne $previousLunaDigest) {
        throw "existing Sol Luna targets do not match install state"
    }
    if (Test-PathExists $terraTarget) {
        if (-not $previousTerraDigest -or (Get-FileDigest $terraTarget) -ne $previousTerraDigest) {
            throw "existing Sol Luna Terra target does not match install state"
        }
    }
    elseif ($previousTerraDigest) {
        throw "existing Sol Luna Terra target does not match install state"
    }
    $previousStatePresent = $true
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
    if (Test-PathExists $legacySkillTarget) {
        if ((Get-TreeDigest $legacySkillTarget) -ne $legacySkillDigest) {
            throw "existing v0.1 skill was modified"
        }
        $legacySkillRemove = $true
    }
    if (Test-PathExists $legacySolTarget) {
        if ((Get-FileDigest $legacySolTarget) -ne $legacySolDigest) {
            throw "existing v0.1 Sol agent was modified"
        }
        $legacySolRemove = $true
    }
}
if (-not $v3StatePresent -and (Test-PathExists $lunaTarget)) {
    if ($previousStatePresent) {
        # The v0.3 state above already proved ownership.
    }
    elseif ($legacyStatePresent) {
        if ((Get-FileDigest $lunaTarget) -ne $legacyLunaDigest) {
            throw "shared Luna was modified; refusing migration"
        }
    }
    else {
        throw "existing shared Luna has no ownership state"
    }
}
if (-not $v3StatePresent -and -not $previousStatePresent -and
    ((Test-PathExists $compatSkillTarget) -or (Test-PathExists $newSolTarget) -or (Test-PathExists $terraTarget))) {
    throw "existing Sol Control target has no supported ownership state"
}

if ($Check) {
    $sourceSkillDigest = Get-TreeDigest $skillSource
    $sourceCompatSkillDigest = Get-TreeDigest $compatSkillSource
    $sourceSolDigest = Get-FileDigest $solSource
    $sourceLunaDigest = Get-FileDigest $lunaSource
    $sourceTerraDigest = Get-FileDigest $terraSource
    if ($v3StatePresent -and
        $v3SkillDigest -eq $sourceSkillDigest -and
        $v3CompatSkillDigest -eq $sourceCompatSkillDigest -and
        $v3SolDigest -eq $sourceSolDigest -and
        $v3LunaDigest -eq $sourceLunaDigest -and
        $v3TerraDigest -and $v3TerraDigest -eq $sourceTerraDigest -and
        -not (Test-PathExists $previousStateFile) -and
        -not (Test-PathExists $legacySkillTarget) -and
        -not (Test-PathExists $legacySolTarget) -and
        -not (Test-PathExists $legacyStateFile)) {
        Write-Output "Check: installation is consistent; no changes required"
        exit 0
    }
    Write-Output "Check: installation is safe and requires install/update"
    exit 2
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
$compatSkillOld = $false
$compatSkillNew = $false
$solOld = $false
$solNew = $false
$lunaOld = $false
$lunaNew = $false
$terraOld = $false
$terraNew = $false
$legacySkillOld = $false
$legacySolOld = $false
$legacyStateOld = $false
$previousStateOld = $false

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
    Ensure-Directory (Join-Path $backupDir "v040")

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
    $legacyStatePresence = "absent"
    $legacyStateBackupDigest = ""
    if (Test-PathExists $legacyStateFile) {
        $legacyStatePresence = "present"
        $legacyStateBackupDigest = Get-FileDigest $legacyStateFile
        Copy-Exact $legacyStateFile (Join-Path $backupDir "legacy/install-state")
    }

    $previousStatePresence = "absent"
    $previousStateBackupDigest = ""
    if (Test-PathExists $previousStateFile) {
        $previousStatePresence = "present"
        $previousStateBackupDigest = Get-FileDigest $previousStateFile
        Copy-Exact $previousStateFile (Join-Path $backupDir "previous-install-state")
    }

    $compatSkillPresence = "absent"
    $compatSkillBackupDigest = ""
    if (Test-PathExists $compatSkillTarget) {
        $compatSkillPresence = "present"
        $compatSkillBackupDigest = Get-TreeDigest $compatSkillTarget
        Copy-Exact $compatSkillTarget (Join-Path $backupDir "compat-skill")
    }

    $v040SkillPresence = "absent"
    $v040SkillBackupDigest = ""
    if (Test-PathExists $newSkillTarget) {
        $v040SkillPresence = "present"
        $v040SkillBackupDigest = Get-TreeDigest $newSkillTarget
        Copy-Exact $newSkillTarget (Join-Path $backupDir "v040/skill")
    }
    $v040StatePresence = "absent"
    $v040StateBackupDigest = ""
    if (Test-PathExists $stateFile) {
        $v040StatePresence = "present"
        $v040StateBackupDigest = Get-FileDigest $stateFile
        Copy-Exact $stateFile (Join-Path $backupDir "v040/install-state")
    }
    $v040SolPresence = "absent"
    $v040SolBackupDigest = ""
    if (Test-PathExists $newSolTarget) {
        $v040SolPresence = "present"
        $v040SolBackupDigest = Get-FileDigest $newSolTarget
        Copy-Exact $newSolTarget (Join-Path $backupDir "v040/sol-controller.toml")
    }
    $v040LunaPresence = $legacyLunaPresence
    $v040LunaBackupDigest = $legacyLunaBackupDigest
    if ($legacyLunaPresence -eq "present") {
        Copy-Exact $lunaTarget (Join-Path $backupDir "v040/luna-max-worker.toml")
    }
    $v040TerraPresence = "absent"
    $v040TerraBackupDigest = ""
    if (Test-PathExists $terraTarget) {
        $v040TerraPresence = "present"
        $v040TerraBackupDigest = Get-FileDigest $terraTarget
        Copy-Exact $terraTarget (Join-Path $backupDir "v040/terra-high-worker.toml")
    }

    $configPresence = "absent"
    $configDigest = ""
    if (Test-PathExists $configTarget) {
        $configPresence = "present"
        $configDigest = Get-FileDigest $configTarget
    }

    $manifest = New-Object System.Collections.Generic.List[string]
    $manifest.Add("version=3")
    $manifest.Add("legacy_skill_presence=$legacySkillPresence")
    $manifest.Add("legacy_skill_sha256=$legacySkillBackupDigest")
    $manifest.Add("legacy_sol_presence=$legacySolPresence")
    $manifest.Add("legacy_sol_sha256=$legacySolBackupDigest")
    $manifest.Add("legacy_luna_presence=$legacyLunaPresence")
    $manifest.Add("legacy_luna_sha256=$legacyLunaBackupDigest")
    $manifest.Add("legacy_state_presence=$legacyStatePresence")
    $manifest.Add("legacy_state_sha256=$legacyStateBackupDigest")
    $manifest.Add("previous_state_presence=$previousStatePresence")
    $manifest.Add("previous_state_sha256=$previousStateBackupDigest")
    $manifest.Add("compat_skill_presence=$compatSkillPresence")
    $manifest.Add("compat_skill_sha256=$compatSkillBackupDigest")
    $manifest.Add("v040_state_presence=$v040StatePresence")
    $manifest.Add("v040_state_sha256=$v040StateBackupDigest")
    $manifest.Add("v040_skill_presence=$v040SkillPresence")
    $manifest.Add("v040_skill_sha256=$v040SkillBackupDigest")
    $manifest.Add("v040_sol_presence=$v040SolPresence")
    $manifest.Add("v040_sol_sha256=$v040SolBackupDigest")
    $manifest.Add("v040_luna_presence=$v040LunaPresence")
    $manifest.Add("v040_luna_sha256=$v040LunaBackupDigest")
    $manifest.Add("v040_terra_presence=$v040TerraPresence")
    $manifest.Add("v040_terra_sha256=$v040TerraBackupDigest")
    $manifest.Add("config_presence=$configPresence")
    $manifest.Add("config_sha256=$configDigest")
    $manifestTemp = Join-Path $backupDir (".manifest-" + [Guid]::NewGuid().ToString("N"))
    Write-Utf8Text $manifestTemp (($manifest -join [Environment]::NewLine) + [Environment]::NewLine)
    Move-Item -LiteralPath $manifestTemp -Destination (Join-Path $backupDir "manifest")
    $manifestTemp = ""

    $transactionDir = Join-Path $stateRoot (".transaction-" + [Guid]::NewGuid().ToString("N"))
    Ensure-Directory $transactionDir
    Ensure-Directory (Join-Path $transactionDir "stage")
    Copy-Exact $skillSource (Join-Path $transactionDir "stage/v040-skill")
    Copy-Exact $compatSkillSource (Join-Path $transactionDir "stage/compat-skill")
    Copy-Exact $solSource (Join-Path $transactionDir "stage/v040-sol-controller.toml")
    Copy-Exact $lunaSource (Join-Path $transactionDir "stage/v040-luna-max-worker.toml")
    Copy-Exact $terraSource (Join-Path $transactionDir "stage/v040-terra-high-worker.toml")

    if (Test-PathExists $stateFile) {
        Move-Item -LiteralPath $stateFile -Destination (Join-Path $transactionDir "old-state")
        $stateOld = $true
    }
    if (Test-PathExists $previousStateFile) {
        Move-Item -LiteralPath $previousStateFile -Destination (Join-Path $transactionDir "old-previous-state")
        $previousStateOld = $true
    }

    if (Test-PathExists $newSkillTarget) {
        Move-Item -LiteralPath $newSkillTarget -Destination (Join-Path $transactionDir "old-v040-skill")
        $skillOld = $true
    }
    Move-Item -LiteralPath (Join-Path $transactionDir "stage/v040-skill") -Destination $newSkillTarget
    $skillNew = $true

    if (Test-PathExists $compatSkillTarget) {
        Move-Item -LiteralPath $compatSkillTarget -Destination (Join-Path $transactionDir "old-compat-skill")
        $compatSkillOld = $true
    }
    Move-Item -LiteralPath (Join-Path $transactionDir "stage/compat-skill") -Destination $compatSkillTarget
    $compatSkillNew = $true

    if ($legacySkillRemove) {
        Move-Item -LiteralPath $legacySkillTarget -Destination (Join-Path $transactionDir "old-legacy-skill")
        $legacySkillOld = $true
    }

    if (Test-PathExists $newSolTarget) {
        Move-Item -LiteralPath $newSolTarget -Destination (Join-Path $transactionDir "old-v040-sol")
        $solOld = $true
    }
    Move-Item -LiteralPath (Join-Path $transactionDir "stage/v040-sol-controller.toml") -Destination $newSolTarget
    $solNew = $true

    if ($legacySolRemove) {
        Move-Item -LiteralPath $legacySolTarget -Destination (Join-Path $transactionDir "old-legacy-sol")
        $legacySolOld = $true
    }
    if (Test-PathExists $legacyStateFile) {
        Move-Item -LiteralPath $legacyStateFile -Destination (Join-Path $transactionDir "old-legacy-state")
        $legacyStateOld = $true
    }

    if (Test-PathExists $lunaTarget) {
        Move-Item -LiteralPath $lunaTarget -Destination (Join-Path $transactionDir "old-luna")
        $lunaOld = $true
    }
    Move-Item -LiteralPath (Join-Path $transactionDir "stage/v040-luna-max-worker.toml") -Destination $lunaTarget
    $lunaNew = $true
    if (Test-PathExists $terraTarget) {
        Move-Item -LiteralPath $terraTarget -Destination (Join-Path $transactionDir "old-terra")
        $terraOld = $true
    }
    Move-Item -LiteralPath (Join-Path $transactionDir "stage/v040-terra-high-worker.toml") -Destination $terraTarget
    $terraNew = $true

    if (-not [string]::IsNullOrWhiteSpace($env:ORCHESTRATE_HOME) -and
        $env:ORCHESTRATE_FAILPOINT -eq "after-replace") {
        throw "injected failure after replacement"
    }

    $newSkillDigest = Get-TreeDigest $newSkillTarget
    $newCompatSkillDigest = Get-TreeDigest $compatSkillTarget
    $newSolDigest = Get-FileDigest $newSolTarget
    $newLunaDigest = Get-FileDigest $lunaTarget
    $newTerraDigest = Get-FileDigest $terraTarget
    Assert-Hash $newSkillDigest
    Assert-Hash $newCompatSkillDigest
    Assert-Hash $newSolDigest
    Assert-Hash $newLunaDigest
    Assert-Hash $newTerraDigest

    $stateTemp = Join-Path $stateRoot (".install-state-" + [Guid]::NewGuid().ToString("N"))
    $stateText = @(
        "version=3",
        "backup_id=$backupId",
        "skill_sha256=$newSkillDigest",
        "compat_skill_sha256=$newCompatSkillDigest",
        "sol_sha256=$newSolDigest",
        "luna_sha256=$newLunaDigest",
        "terra_sha256=$newTerraDigest"
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
    if ($terraNew) { Remove-Exact $terraTarget }
    if ($terraOld -and (Test-PathExists (Join-Path $transactionDir "old-terra"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-terra") -Destination $terraTarget
    }
    if ($solNew) { Remove-Exact $newSolTarget }
    if ($solOld -and (Test-PathExists (Join-Path $transactionDir "old-v040-sol"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-v040-sol") -Destination $newSolTarget
    }
    if ($skillNew) { Remove-Exact $newSkillTarget }
    if ($skillOld -and (Test-PathExists (Join-Path $transactionDir "old-v040-skill"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-v040-skill") -Destination $newSkillTarget
    }
    if ($compatSkillNew) { Remove-Exact $compatSkillTarget }
    if ($compatSkillOld -and (Test-PathExists (Join-Path $transactionDir "old-compat-skill"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-compat-skill") -Destination $compatSkillTarget
    }
    if ($legacySolOld -and (Test-PathExists (Join-Path $transactionDir "old-legacy-sol"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-legacy-sol") -Destination $legacySolTarget
    }
    if ($legacySkillOld -and (Test-PathExists (Join-Path $transactionDir "old-legacy-skill"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-legacy-skill") -Destination $legacySkillTarget
    }
    if ($legacyStateOld -and (Test-PathExists (Join-Path $transactionDir "old-legacy-state"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-legacy-state") -Destination $legacyStateFile
    }
    if ($previousStateOld -and (Test-PathExists (Join-Path $transactionDir "old-previous-state"))) {
        Move-Item -LiteralPath (Join-Path $transactionDir "old-previous-state") -Destination $previousStateFile
    }
    if ($transactionDir -and (Test-PathExists $transactionDir)) { Remove-Exact $transactionDir }
    if (Test-PathExists $backupDir) { Remove-Exact $backupDir }
    Remove-EmptyCreatedDirectories
    throw
}

Remove-EmptyDirectory $legacyStateRoot
Remove-EmptyDirectory $previousStateRoot

Write-Output "Install path: $newSkillTarget"
Write-Output "Compatibility path: $compatSkillTarget"
Write-Output "Install path: $newSolTarget"
Write-Output "Install path: $lunaTarget"
Write-Output "Install path: $terraTarget"
Write-Output "Backup path: $backupDir"
