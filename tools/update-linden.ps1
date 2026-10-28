# Linden RP Windows auto-updater. Only updates resources/[local]/linden_rp.
# Does not update SQL, ESX, FivePRS, ox_lib, server.cfg or txAdmin itself.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ServerDataPath,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$serverData = [IO.Path]::GetFullPath($ServerDataPath)
$target = Join-Path $serverData 'resources\[local]\linden_rp'
$updateDirectory = Join-Path $serverData '.linden-updater'
$stateFile = Join-Path $updateDirectory 'installed-commit.txt'
$logFile = Join-Path $updateDirectory 'updater.log'
$lockFile = Join-Path $updateDirectory 'updater.lock'
$repo = 'fynn-2557/linden-rp'

if (-not (Test-Path -LiteralPath (Join-Path $target 'fxmanifest.lua') -PathType Leaf)) {
    throw "Linden RP not found at $target. Use the txAdmin server-data directory containing resources."
}
New-Item -ItemType Directory -Path $updateDirectory -Force | Out-Null

function Write-UpdateLog([string]$Message) {
    $line = ('{0} {1}' -f [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'), $Message)
    Write-Host $line
    [IO.File]::AppendAllText($logFile, $line + [Environment]::NewLine)
}
try {
    $lock = [IO.File]::Open($lockFile, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
} catch [IO.IOException] {
    Write-Host 'Another Linden updater is already running; skipping this check.'
    exit 0
}

$work = $null
try {
    Write-UpdateLog 'Update check started.'
    $headers = @{
        'User-Agent' = 'LindenRP-Windows-Updater'
        'Accept' = 'application/vnd.github+json'
    }
    $commit = Invoke-RestMethod -Uri ('https://api.github.com/repos/{0}/commits/main' -f $repo) -Headers $headers -TimeoutSec 30
    $sha = [string]$commit.sha
    if ($sha -notmatch '^[a-fA-F0-9]{40}$') {
        throw 'GitHub did not return a valid commit SHA.'
    }
    $previousSha = ''
    if (Test-Path -LiteralPath $stateFile) {
        $previousSha = ([IO.File]::ReadAllText($stateFile)).Trim()
    }
    if ($previousSha -eq $sha) {
        Write-UpdateLog ('Current: {0}; no update.' -f $sha.Substring(0, 12))
        return
    }
    if ($CheckOnly) {
        Write-UpdateLog ('Update available: installed={0}; latest={1}' -f $previousSha, $sha)
        return
    }

    Write-UpdateLog ('Downloading commit {0}.' -f $sha.Substring(0, 12))
    $work = Join-Path $updateDirectory ('work-' + [guid]::NewGuid().ToString('N'))
    $extract = Join-Path $work 'extract'
    $zipFile = Join-Path $work 'source.zip'
    New-Item -ItemType Directory -Path $extract -Force | Out-Null

    Invoke-WebRequest -Uri ('https://github.com/{0}/archive/{1}.zip' -f $repo, $sha) -OutFile $zipFile -UseBasicParsing -TimeoutSec 120
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $extract)
    $repoDirectory = @(Get-ChildItem -LiteralPath $extract -Directory)
    if ($repoDirectory.Count -ne 1) { throw 'Unexpected GitHub archive structure.' }
    $source = Join-Path $repoDirectory[0].FullName 'linden_rp'
    if (-not (Test-Path -LiteralPath (Join-Path $source 'fxmanifest.lua') -PathType Leaf)) {
        throw 'Archive does not contain a valid Linden RP resource.'
    }
    $stage = Join-Path $work 'new-resource'
    Copy-Item -LiteralPath $source -Destination $stage -Recurse -Force

    # These are local runtime data. Never delete or replace them from GitHub.
    $preserve = @(
        '.env',
        'bot\.env',
        'bot\data',
        'bot\logs',
        'bot\node_modules',
        'data',
        'logs'
    )
    foreach ($relative in $preserve) {
        $existing = Join-Path $target $relative
        if (-not (Test-Path -LiteralPath $existing)) { continue }
        $destination = Join-Path $stage $relative
        $destinationParent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $destinationParent)) {
            New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        }
        if (Test-Path -LiteralPath $destination) {
            Remove-Item -LiteralPath $destination -Recurse -Force
        }
        Copy-Item -LiteralPath $existing -Destination $destination -Recurse -Force
    }

    $backupRoot = Join-Path $updateDirectory 'backups'
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmss')
    $backupPath = Join-Path $backupRoot ('linden_rp_{0}_{1}' -f $timestamp, $sha.Substring(0, 8))
    if (Test-Path -LiteralPath $backupPath) { throw "Backup folder already exists: $backupPath" }

    $oldMoved = $false
    try {
        # The old version stays available as a full rollback copy.
        Move-Item -LiteralPath $target -Destination $backupPath -ErrorAction Stop
        $oldMoved = $true
        Move-Item -LiteralPath $stage -Destination $target -ErrorAction Stop
        [IO.File]::WriteAllText($stateFile, $sha + [Environment]::NewLine)
    } catch {
        # Restore old resource if activation could not complete.
        if ($oldMoved -and -not (Test-Path -LiteralPath $target) -and (Test-Path -LiteralPath $backupPath)) {
            Move-Item -LiteralPath $backupPath -Destination $target -ErrorAction Stop
        }
        throw
    }

    Write-UpdateLog ('Installed {0}; changes take effect at the next txAdmin restart. Backup: {1}' -f $sha.Substring(0, 12), $backupPath)
    # Retain five most recent backups.
    @(Get-ChildItem -LiteralPath $backupRoot -Directory |
        Sort-Object -Property LastWriteTimeUtc -Descending |
        Select-Object -Skip 5) | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force
        }
} catch {
    Write-UpdateLog ('ERROR: ' + $_.Exception.Message)
    exit 1
} finally {
    if ($work -and (Test-Path -LiteralPath $work)) {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($lock) { $lock.Dispose() }
}
