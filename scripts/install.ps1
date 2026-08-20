#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-PathExists {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Test-Path -LiteralPath $Path)
}

function Test-ReparsePoint {
    param([Parameter(Mandatory = $true)]$Item)
    return (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Assert-PlainPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][ValidateSet("Directory", "File")][string]$Kind
    )
    if (-not (Test-PathExists $Path)) { return }
    $item = Get-Item -LiteralPath $Path -Force
    if (Test-ReparsePoint $item) { throw "reparse points are not allowed in managed paths" }
    if ($Kind -eq "Directory" -and -not $item.PSIsContainer) { throw "a managed directory has the wrong type" }
    if ($Kind -eq "File" -and $item.PSIsContainer) { throw "a managed file has the wrong type" }
    if ($item.PSIsContainer) {
        Get-ChildItem -LiteralPath $Path -Force -Recurse | ForEach-Object {
            if (Test-ReparsePoint $_) { throw "reparse points are not allowed in managed trees" }
        }
    }
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-PathExists $Path) {
        Assert-PlainPath $Path "Directory"
        return
    }
    $parent = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $Path) { throw "cannot create install directory" }
    Ensure-Directory $parent
    [System.IO.Directory]::CreateDirectory($Path) | Out-Null
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
    Assert-PlainPath $Path "Directory"
    $entries = New-Object System.Collections.Generic.List[string]
    foreach ($item in @(Get-ChildItem -LiteralPath $Path -Force -Recurse | Sort-Object -Property FullName)) {
        $relative = $item.FullName.Substring($Path.Length).TrimStart([char[]]"/\").Replace("\", "/")
        if ($item.PSIsContainer) {
            $entries.Add("D`t$relative`n")
        }
        else {
            $entries.Add("F`t$relative`t$(Get-FileDigest $item.FullName)`n")
        }
    }
    return Get-BytesDigest ([System.Text.Encoding]::UTF8.GetBytes(($entries -join "")))
}

function Get-PathDigest {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][ValidateSet("Directory", "File")][string]$Kind
    )
    if ($Kind -eq "Directory") { return Get-TreeDigest $Path }
    return Get-FileDigest $Path
}

function Copy-Exact {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    $sourceItem = Get-Item -LiteralPath $Source -Force
    Assert-PlainPath $Source $(if ($sourceItem.PSIsContainer) { "Directory" } else { "File" })
    if ($sourceItem.PSIsContainer) {
        Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
    }
    else {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
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
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -notmatch "^(?<key>[A-Za-z_][A-Za-z0-9_]*)=(?<value>.*)$") { throw "invalid install state" }
        if ($map.ContainsKey($Matches.key)) { throw "duplicate install state key" }
        $map[$Matches.key] = $Matches.value
    }
    return $map
}

function Get-StateValue {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Map,
        [Parameter(Mandatory = $true)][string]$Key
    )
    if (-not $Map.ContainsKey($Key)) { throw "install state is incomplete" }
    return [string]$Map[$Key]
}

function Get-OptionalStateValue {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Map,
        [Parameter(Mandatory = $true)][string]$Key
    )
    if (-not $Map.ContainsKey($Key)) { return "" }
    return [string]$Map[$Key]
}

function Assert-Hash {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ($Value -notmatch "^[0-9a-f]{64}$") { throw "invalid checksum" }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$validateScript = Join-Path $PSScriptRoot "validate.ps1"
& $validateScript
if ($LASTEXITCODE -ne 0) { throw "source validation failed" }

$canonicalSkillSource = Join-Path $repoRoot ".agents/skills/codex-prove"
$compatSkillSource = Join-Path $repoRoot ".agents/skills/sol-control"
$controllerSource = Join-Path $repoRoot ".codex/agents/prove-controller.toml"
$complexSource = Join-Path $repoRoot ".codex/agents/prove-complex-worker.toml"
$efficientSource = Join-Path $repoRoot ".codex/agents/prove-efficient-worker.toml"
foreach ($path in @($canonicalSkillSource, $compatSkillSource)) { Assert-PlainPath $path "Directory" }
foreach ($path in @($controllerSource, $complexSource, $efficientSource)) { Assert-PlainPath $path "File" }

$rawBase = $env:ORCHESTRATE_HOME
if ([string]::IsNullOrWhiteSpace($rawBase)) { $rawBase = [Environment]::GetFolderPath("UserProfile") }
if ([string]::IsNullOrWhiteSpace($rawBase) -or -not [System.IO.Path]::IsPathRooted($rawBase)) { throw "ORCHESTRATE_HOME must be an absolute path" }
$baseDir = [System.IO.Path]::GetFullPath($rawBase)
if ($baseDir -eq [System.IO.Path]::GetPathRoot($baseDir)) { throw "refusing the filesystem root as ORCHESTRATE_HOME" }
if (Test-PathExists $baseDir) { Assert-PlainPath $baseDir "Directory" }
foreach ($parent in @(
    (Join-Path $baseDir ".agents"),
    (Join-Path $baseDir ".agents/skills"),
    (Join-Path $baseDir ".codex"),
    (Join-Path $baseDir ".codex/agents"),
    (Join-Path $baseDir ".codex/codex-prove")
)) {
    if (Test-PathExists $parent) { Assert-PlainPath $parent "Directory" }
}

$relativePaths = @(
    ".agents/skills/codex-prove",
    ".agents/skills/sol-control",
    ".agents/skills/sol-luna",
    ".agents/skills/orchestrate-sol-luna",
    ".codex/agents/prove-controller.toml",
    ".codex/agents/prove-complex-worker.toml",
    ".codex/agents/prove-efficient-worker.toml",
    ".codex/agents/sol-controller.toml",
    ".codex/agents/terra-high-worker.toml",
    ".codex/agents/luna-max-worker.toml",
    ".codex/agents/sol-planner.toml",
    ".codex/codex-prove/install-state",
    ".codex/sol-control/install-state",
    ".codex/sol-luna/install-state",
    ".codex/orchestrate-sol-luna/install-state"
)
$kinds = @(
    "Directory", "Directory", "Directory", "Directory",
    "File", "File", "File", "File", "File", "File", "File",
    "File", "File", "File", "File"
)
$owned = New-Object bool[] $relativePaths.Count

for ($index = 0; $index -lt $relativePaths.Count; $index++) {
    $target = Join-Path $baseDir $relativePaths[$index]
    if (Test-PathExists $target) { Assert-PlainPath $target $kinds[$index] }
}

$stateIndexes = @(11, 12, 13, 14)
$activeStateIndex = -1
foreach ($index in $stateIndexes) {
    if (Test-PathExists (Join-Path $baseDir $relativePaths[$index])) {
        if ($activeStateIndex -ge 0) { throw "multiple managed install states exist" }
        $activeStateIndex = $index
    }
}

function Set-OwnedTarget {
    param(
        [Parameter(Mandatory = $true)][int]$Index,
        [Parameter(Mandatory = $true)][string]$Expected
    )
    Assert-Hash $Expected
    $target = Join-Path $baseDir $relativePaths[$Index]
    if (-not (Test-PathExists $target)) { throw "a state-owned target is missing" }
    if ((Get-PathDigest $target $kinds[$Index]) -ne $Expected) { throw "a state-owned target was modified" }
    $owned[$Index] = $true
}

if ($activeStateIndex -ge 0) {
    $activeStatePath = Join-Path $baseDir $relativePaths[$activeStateIndex]
    $state = Get-StateMap $activeStatePath
    $version = Get-StateValue $state "version"
    if ($activeStateIndex -eq 11 -and $version -eq "5") {
        Set-OwnedTarget 0 (Get-StateValue $state "skill_sha256")
        Set-OwnedTarget 1 (Get-StateValue $state "compat_skill_sha256")
        Set-OwnedTarget 4 (Get-StateValue $state "controller_sha256")
        Set-OwnedTarget 5 (Get-StateValue $state "complex_worker_sha256")
        Set-OwnedTarget 6 (Get-StateValue $state "efficient_worker_sha256")
        $owned[11] = $true
    }
    elseif ($activeStateIndex -eq 12 -and @("3", "4") -contains $version) {
        Set-OwnedTarget 1 (Get-StateValue $state "skill_sha256")
        Set-OwnedTarget 7 (Get-StateValue $state "sol_sha256")
        Set-OwnedTarget 9 (Get-StateValue $state "luna_sha256")
        $terraHash = Get-OptionalStateValue $state "terra_sha256"
        if (-not [string]::IsNullOrEmpty($terraHash)) { Set-OwnedTarget 8 $terraHash }
        if ($version -eq "3") { Set-OwnedTarget 2 (Get-StateValue $state "compat_skill_sha256") }
        $owned[12] = $true
    }
    elseif ($activeStateIndex -eq 13 -and $version -eq "2") {
        Set-OwnedTarget 2 (Get-StateValue $state "skill_sha256")
        Set-OwnedTarget 7 (Get-StateValue $state "sol_sha256")
        Set-OwnedTarget 9 (Get-StateValue $state "luna_sha256")
        $terraHash = Get-OptionalStateValue $state "terra_sha256"
        if (-not [string]::IsNullOrEmpty($terraHash)) { Set-OwnedTarget 8 $terraHash }
        $owned[13] = $true
    }
    elseif ($activeStateIndex -eq 14 -and $version -eq "1") {
        Set-OwnedTarget 3 (Get-StateValue $state "skill_sha256")
        Set-OwnedTarget 10 (Get-StateValue $state "sol_sha256")
        Set-OwnedTarget 9 (Get-StateValue $state "luna_sha256")
        $owned[14] = $true
    }
    else {
        throw "unsupported managed install state"
    }
}

for ($index = 0; $index -lt $relativePaths.Count; $index++) {
    $target = Join-Path $baseDir $relativePaths[$index]
    if ((Test-PathExists $target) -and -not $owned[$index]) {
        throw "an existing target has no matching ownership state: $($relativePaths[$index])"
    }
}

if ($Check) {
    Write-Output "Install check: OK"
    Write-Output "Install path: $(Join-Path $baseDir '.agents/skills/codex-prove')"
    exit 0
}

$skillsDir = Join-Path $baseDir ".agents/skills"
$agentsDir = Join-Path $baseDir ".codex/agents"
$stateRoot = Join-Path $baseDir ".codex/codex-prove"
$backupRoot = Join-Path $stateRoot "backups"
foreach ($directory in @($skillsDir, $agentsDir, $stateRoot, $backupRoot)) { Ensure-Directory $directory }

$backupId = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ") + "-" + $PID
$backupDir = Join-Path $backupRoot $backupId
if (Test-PathExists $backupDir) {
    $backupId += "-" + [Guid]::NewGuid().ToString("N")
    $backupDir = Join-Path $backupRoot $backupId
}
Ensure-Directory $backupDir
$entriesDir = Join-Path $backupDir "entries"
Ensure-Directory $entriesDir

$manifestLines = New-Object System.Collections.Generic.List[string]
$manifestLines.Add("version=5")
$manifestLines.Add("entry_count=$($relativePaths.Count)")
for ($index = 0; $index -lt $relativePaths.Count; $index++) {
    $number = $index + 1
    $target = Join-Path $baseDir $relativePaths[$index]
    $presence = "absent"
    $digest = ""
    if (Test-PathExists $target) {
        $presence = "present"
        $digest = Get-PathDigest $target $kinds[$index]
        Copy-Exact $target (Join-Path $entriesDir ([string]$number))
    }
    $manifestLines.Add("entry_${number}_path=$($relativePaths[$index])")
    $manifestLines.Add("entry_${number}_kind=$($kinds[$index].ToLowerInvariant())")
    $manifestLines.Add("entry_${number}_presence=$presence")
    $manifestLines.Add("entry_${number}_sha256=$digest")
}

$configTarget = Join-Path $baseDir ".codex/config.toml"
if (Test-PathExists $configTarget) {
    Assert-PlainPath $configTarget "File"
    $configDigest = Get-FileDigest $configTarget
    Copy-Exact $configTarget (Join-Path $backupDir "config.toml")
    $manifestLines.Add("config_presence=present")
    $manifestLines.Add("config_sha256=$configDigest")
}
else {
    $manifestLines.Add("config_presence=absent")
    $manifestLines.Add("config_sha256=")
}
Write-Utf8Text (Join-Path $backupDir "manifest") (($manifestLines -join "`n") + "`n")

$transactionDir = Join-Path $stateRoot (".transaction." + [Guid]::NewGuid().ToString("N"))
$stageDir = Join-Path $transactionDir "stage"
$oldDir = Join-Path $transactionDir "old"
$failedDir = Join-Path $transactionDir "failed"
foreach ($directory in @($transactionDir, $stageDir, $oldDir, $failedDir)) { Ensure-Directory $directory }
Copy-Exact $canonicalSkillSource (Join-Path $stageDir "codex-prove")
Copy-Exact $compatSkillSource (Join-Path $stageDir "sol-control")
Copy-Exact $controllerSource (Join-Path $stageDir "prove-controller.toml")
Copy-Exact $complexSource (Join-Path $stageDir "prove-complex-worker.toml")
Copy-Exact $efficientSource (Join-Path $stageDir "prove-efficient-worker.toml")

try {
    for ($index = 0; $index -lt $relativePaths.Count; $index++) {
        $target = Join-Path $baseDir $relativePaths[$index]
        if (Test-PathExists $target) { Move-Item -LiteralPath $target -Destination (Join-Path $oldDir ([string]$index)) }
    }

    Move-Item -LiteralPath (Join-Path $stageDir "codex-prove") -Destination (Join-Path $baseDir $relativePaths[0])
    Move-Item -LiteralPath (Join-Path $stageDir "sol-control") -Destination (Join-Path $baseDir $relativePaths[1])
    Move-Item -LiteralPath (Join-Path $stageDir "prove-controller.toml") -Destination (Join-Path $baseDir $relativePaths[4])
    Move-Item -LiteralPath (Join-Path $stageDir "prove-complex-worker.toml") -Destination (Join-Path $baseDir $relativePaths[5])
    Move-Item -LiteralPath (Join-Path $stageDir "prove-efficient-worker.toml") -Destination (Join-Path $baseDir $relativePaths[6])

    if ($env:ORCHESTRATE_FAILPOINT -eq "after-replace") { throw "injected failure after replacement" }

    $skillHash = Get-TreeDigest (Join-Path $baseDir $relativePaths[0])
    $compatHash = Get-TreeDigest (Join-Path $baseDir $relativePaths[1])
    $controllerHash = Get-FileDigest (Join-Path $baseDir $relativePaths[4])
    $complexHash = Get-FileDigest (Join-Path $baseDir $relativePaths[5])
    $efficientHash = Get-FileDigest (Join-Path $baseDir $relativePaths[6])
    foreach ($digest in @($skillHash, $compatHash, $controllerHash, $complexHash, $efficientHash)) { Assert-Hash $digest }

    $stateText = @(
        "version=5",
        "backup_id=$backupId",
        "skill_sha256=$skillHash",
        "compat_skill_sha256=$compatHash",
        "controller_sha256=$controllerHash",
        "complex_worker_sha256=$complexHash",
        "efficient_worker_sha256=$efficientHash"
    ) -join "`n"
    $stateTemp = Join-Path $stateRoot (".install-state." + [Guid]::NewGuid().ToString("N"))
    Write-Utf8Text $stateTemp ($stateText + "`n")
    Move-Item -LiteralPath $stateTemp -Destination (Join-Path $baseDir $relativePaths[11])

    if ($env:ORCHESTRATE_FAILPOINT -eq "after-state") { throw "injected failure after state" }
}
catch {
    for ($index = $relativePaths.Count - 1; $index -ge 0; $index--) {
        $target = Join-Path $baseDir $relativePaths[$index]
        if (Test-PathExists $target) {
            Ensure-Directory (Join-Path $failedDir ([string]$index))
            Move-Item -LiteralPath $target -Destination (Join-Path (Join-Path $failedDir ([string]$index)) "current") -ErrorAction SilentlyContinue
        }
        $old = Join-Path $oldDir ([string]$index)
        if (Test-PathExists $old) {
            Ensure-Directory (Split-Path -Parent $target)
            Move-Item -LiteralPath $old -Destination $target -ErrorAction SilentlyContinue
        }
    }
    if (Test-PathExists $transactionDir) { Remove-Item -LiteralPath $transactionDir -Recurse -Force }
    throw
}

Remove-Item -LiteralPath $transactionDir -Recurse -Force
Write-Output "Install path: $(Join-Path $baseDir $relativePaths[0])"
Write-Output "Compatibility path: $(Join-Path $baseDir $relativePaths[1])"
Write-Output "Agent path: $(Join-Path $baseDir $relativePaths[4])"
Write-Output "Agent path: $(Join-Path $baseDir $relativePaths[5])"
Write-Output "Agent path: $(Join-Path $baseDir $relativePaths[6])"
Write-Output "Backup path: $backupDir"
