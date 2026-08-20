#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$RestoreLatest
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
    if (-not (Test-PathExists $Path)) { throw "managed path is missing" }
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
        $item = Get-Item -LiteralPath $Path -Force
        if (-not $item.PSIsContainer -or (Test-ReparsePoint $item)) { throw "unsafe directory" }
        return
    }
    $parent = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $Path) { throw "cannot create directory" }
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
    try { return ([System.BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-TreeDigest {
    param([Parameter(Mandatory = $true)][string]$Path)
    Assert-PlainPath $Path "Directory"
    $entries = New-Object System.Collections.Generic.List[string]
    foreach ($item in @(Get-ChildItem -LiteralPath $Path -Force -Recurse | Sort-Object -Property FullName)) {
        $relative = $item.FullName.Substring($Path.Length).TrimStart([char[]]"/\").Replace("\", "/")
        if ($item.PSIsContainer) { $entries.Add("D`t$relative`n") }
        else { $entries.Add("F`t$relative`t$(Get-FileDigest $item.FullName)`n") }
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
    $item = Get-Item -LiteralPath $Source -Force
    if ($item.PSIsContainer) { Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force }
    else { Copy-Item -LiteralPath $Source -Destination $Destination -Force }
}

function Get-StateMap {
    param([Parameter(Mandatory = $true)][string]$Path)
    $map = @{}
    foreach ($line in @(Get-Content -LiteralPath $Path)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -notmatch "^(?<key>[A-Za-z_][A-Za-z0-9_]*)=(?<value>.*)$") { throw "invalid state or manifest" }
        if ($map.ContainsKey($Matches.key)) { throw "duplicate state or manifest key" }
        $map[$Matches.key] = $Matches.value
    }
    return $map
}

function Get-StateValue {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Map,
        [Parameter(Mandatory = $true)][string]$Key
    )
    if (-not $Map.ContainsKey($Key)) { throw "state or manifest is incomplete" }
    return [string]$Map[$Key]
}

function Assert-Hash {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ($Value -notmatch "^[0-9a-f]{64}$") { throw "invalid checksum" }
}

$rawBase = $env:ORCHESTRATE_HOME
if ([string]::IsNullOrWhiteSpace($rawBase)) { $rawBase = [Environment]::GetFolderPath("UserProfile") }
if ([string]::IsNullOrWhiteSpace($rawBase) -or -not [System.IO.Path]::IsPathRooted($rawBase)) { throw "ORCHESTRATE_HOME must be an absolute path" }
$baseDir = [System.IO.Path]::GetFullPath($rawBase)
if ($baseDir -eq [System.IO.Path]::GetPathRoot($baseDir)) { throw "refusing the filesystem root" }
Assert-PlainPath $baseDir "Directory"

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
$managedIndexes = @(0, 1, 4, 5, 6)
$managedKeys = @("skill_sha256", "compat_skill_sha256", "controller_sha256", "complex_worker_sha256", "efficient_worker_sha256")

$stateRoot = Join-Path $baseDir ".codex/codex-prove"
$stateFile = Join-Path $stateRoot "install-state"
$backupRoot = Join-Path $stateRoot "backups"
Assert-PlainPath $stateFile "File"
$state = Get-StateMap $stateFile
if ((Get-StateValue $state "version") -ne "5") { throw "unsupported Codex PROVE install state" }
$backupId = Get-StateValue $state "backup_id"
if ($backupId -notmatch "^[A-Za-z0-9._-]+$" -or $backupId -eq "." -or $backupId -eq "..") { throw "unsafe backup identifier" }

for ($item = 0; $item -lt $managedIndexes.Count; $item++) {
    $index = $managedIndexes[$item]
    $target = Join-Path $baseDir $relativePaths[$index]
    $expected = Get-StateValue $state $managedKeys[$item]
    Assert-Hash $expected
    Assert-PlainPath $target $kinds[$index]
    if ((Get-PathDigest $target $kinds[$index]) -ne $expected) { throw "an installed target was modified; refusing removal" }
}

$backupDir = Join-Path $backupRoot $backupId
$manifestPath = Join-Path $backupDir "manifest"
$manifest = $null
if ($RestoreLatest) {
    Assert-PlainPath $backupDir "Directory"
    Assert-PlainPath $manifestPath "File"
    $manifest = Get-StateMap $manifestPath
    if ((Get-StateValue $manifest "version") -ne "5") { throw "unsupported backup manifest" }
    if ((Get-StateValue $manifest "entry_count") -ne [string]$relativePaths.Count) { throw "backup manifest has the wrong entry count" }
}

$transactionDir = Join-Path $stateRoot (".uninstall." + [Guid]::NewGuid().ToString("N"))
$currentDir = Join-Path $transactionDir "current"
$stageDir = Join-Path $transactionDir "stage"
$failedDir = Join-Path $transactionDir "failed"
foreach ($directory in @($transactionDir, $currentDir, $stageDir, $failedDir)) { Ensure-Directory $directory }

if ($RestoreLatest) {
    for ($index = 0; $index -lt $relativePaths.Count; $index++) {
        $number = $index + 1
        $recordedPath = Get-StateValue $manifest "entry_${number}_path"
        $recordedKind = Get-StateValue $manifest "entry_${number}_kind"
        $presence = Get-StateValue $manifest "entry_${number}_presence"
        $digest = Get-StateValue $manifest "entry_${number}_sha256"
        if ($recordedPath -ne $relativePaths[$index]) { throw "backup manifest contains an unsafe path" }
        if ($recordedKind -ne $kinds[$index].ToLowerInvariant()) { throw "backup manifest contains an invalid kind" }
        if (@("present", "absent") -notcontains $presence) { throw "backup manifest contains an invalid presence" }
        $source = Join-Path (Join-Path $backupDir "entries") ([string]$number)
        if ($presence -eq "present") {
            Assert-Hash $digest
            Assert-PlainPath $source $kinds[$index]
            if ((Get-PathDigest $source $kinds[$index]) -ne $digest) { throw "backup entry checksum mismatch" }
            Copy-Exact $source (Join-Path $stageDir ([string]$index))
        }
        else {
            if (-not [string]::IsNullOrEmpty($digest) -or (Test-PathExists $source)) { throw "absent backup entry is inconsistent" }
        }
    }
}

try {
    foreach ($index in @($managedIndexes + 11)) {
        $target = Join-Path $baseDir $relativePaths[$index]
        Move-Item -LiteralPath $target -Destination (Join-Path $currentDir ([string]$index))
    }

    if ($RestoreLatest) {
        for ($index = 0; $index -lt $relativePaths.Count; $index++) {
            $source = Join-Path $stageDir ([string]$index)
            if (Test-PathExists $source) {
                $target = Join-Path $baseDir $relativePaths[$index]
                if (Test-PathExists $target) { throw "restore target unexpectedly exists" }
                Ensure-Directory (Split-Path -Parent $target)
                Move-Item -LiteralPath $source -Destination $target
            }
        }
    }

    if ($env:ORCHESTRATE_FAILPOINT -eq "after-remove") { throw "injected failure after removal" }
}
catch {
    for ($index = $relativePaths.Count - 1; $index -ge 0; $index--) {
        $target = Join-Path $baseDir $relativePaths[$index]
        if (Test-PathExists $target) {
            Ensure-Directory (Join-Path $failedDir ([string]$index))
            Move-Item -LiteralPath $target -Destination (Join-Path (Join-Path $failedDir ([string]$index)) "current") -ErrorAction SilentlyContinue
        }
        $current = Join-Path $currentDir ([string]$index)
        if (Test-PathExists $current) {
            Ensure-Directory (Split-Path -Parent $target)
            Move-Item -LiteralPath $current -Destination $target -ErrorAction SilentlyContinue
        }
    }
    if (Test-PathExists $transactionDir) { Remove-Item -LiteralPath $transactionDir -Recurse -Force }
    throw
}

Remove-Item -LiteralPath $transactionDir -Recurse -Force
Write-Output "Uninstalled current Codex PROVE version"
if ($RestoreLatest) { Write-Output "Restored backup: $backupDir" }
