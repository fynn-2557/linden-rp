# Scheduler stages only. Offline activation is an explicit maintenance operation.
[CmdletBinding()]
param(
    [string]$ServerDataPath,
    [ValidateSet('Stage','Check','Activate','Rollback')][string]$Mode = 'Stage',
    [string]$ExpectedSha,
    [switch]$ServerStopped,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Assert-ChildPath($Root, $Path) {
    $r = [IO.Path]::GetFullPath($Root).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    $p = [IO.Path]::GetFullPath($Path)
    if (-not $p.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes updater root.' }
    $cursor = $p
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse points are not supported.' }
        }
        $parent = Split-Path -Parent $cursor
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
    return $p
}

function Write-AtomicText($Path, $Text) {
    $tmp = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    [IO.File]::WriteAllText($tmp, $Text, (New-Object Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($tmp, $Path, ($Path + '.previous')) }
    else { [IO.File]::Move($tmp, $Path) }
}

function Assert-Offline($Confirmed) {
    if (-not $Confirmed) { throw 'Explicit -ServerStopped required. Keep txAdmin and bot supervisors stopped during maintenance.' }
    if (Get-Process -Name FXServer -ErrorAction SilentlyContinue) { throw 'FXServer is running; activation refused.' }
    # The bot writes resource-local runtime data too. Conservatively block any Node process.
    if (Get-Process -Name node -ErrorAction SilentlyContinue) { throw 'Node is running; stop the bot supervisor before activation.' }
}

function Get-LatestCommit {
    $headers = @{ 'User-Agent'='LindenRP-Windows-Updater'; 'Accept'='application/vnd.github+json' }
    return [string](Invoke-RestMethod -Uri 'https://api.github.com/repos/fynn-2557/linden-rp/commits/main' -Headers $headers -TimeoutSec 30).sha
}

function Get-ResourceSnapshot($Sha, $Destination) {
    $zip = Join-Path $Destination 'source.zip'
    Invoke-WebRequest -Uri ('https://github.com/fynn-2557/linden-rp/archive/{0}.zip' -f $Sha) -OutFile $zip -UseBasicParsing -TimeoutSec 120
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $extract = Join-Path $Destination 'extract'
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $extract)
    $dirs = @(Get-ChildItem -LiteralPath $extract -Directory)
    if ($dirs.Count -ne 1) { throw 'Unexpected archive layout.' }
    return (Join-Path $dirs[0].FullName 'linden_rp')
}

function Get-Inventory($Root) {
    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd('\','/')
    $result = @{}
    foreach ($item in Get-ChildItem -LiteralPath $Root -Recurse -Force) {
        $null = Assert-ChildPath $rootPath $item.FullName
        if ($item.PSIsContainer) { continue }
        $rel = $item.FullName.Substring($rootPath.Length + 1).Replace('\','/')
        $result[$rel] = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    }
    return $result
}

function Assert-Inventory($Root, $Expected) {
    $actual = Get-Inventory $Root
    $properties = @($Expected.PSObject.Properties)
    if ($actual.Count -ne $properties.Count) { throw 'Staged file inventory changed.' }
    foreach ($p in $properties) {
        if ($actual[$p.Name] -ne $p.Value) { throw ('Staged hash mismatch: ' + $p.Name) }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Root 'fxmanifest.lua'))) { throw 'Missing resource manifest.' }
}

function Copy-RuntimeData($From, $To) {
    foreach ($rel in @('.env','bot/.env','bot/data','bot/logs','bot/node_modules','data','logs')) {
        $src = Assert-ChildPath $From (Join-Path $From $rel)
        $dest = Assert-ChildPath $To (Join-Path $To $rel)
        if (-not (Test-Path -LiteralPath $src)) { continue }
        if ((Get-Item -LiteralPath $src).PSIsContainer) { $null = Get-Inventory $src }
        if (Test-Path -LiteralPath $dest) { throw ('Release contains protected runtime path: ' + $rel) }
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force
        Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
    }
}

function Copy-CodeOnly($From, $To) {
    $inventory = Get-Inventory $From
    $null = New-Item -ItemType Directory -Path $To
    foreach ($rel in $inventory.Keys) {
        if ($rel -match '^(\.env$|bot/\.env$|bot/(data|logs|node_modules)(/|$)|(data|logs)(/|$))') { continue }
        $dest = Assert-ChildPath $To (Join-Path $To $rel)
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force
        Copy-Item -LiteralPath (Join-Path $From $rel) -Destination $dest
    }
}

function Invoke-LindenUpdate($DataPath, $Action, $ApprovedSha, $OfflineConfirmed) {
    if (-not $DataPath) { throw 'ServerDataPath required.' }
    $data = [IO.Path]::GetFullPath($DataPath)
    $target = Assert-ChildPath $data (Join-Path $data 'resources/[local]/linden_rp')
    if ($Action -ne 'Rollback' -and -not (Test-Path -LiteralPath (Join-Path $target 'fxmanifest.lua'))) { throw 'Linden resource missing.' }
    $up = Assert-ChildPath $data (Join-Path $data '.linden-updater')
    $null = New-Item -ItemType Directory -Path $up -Force
    $lockPath = Join-Path $up 'updater.lock'
    $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    try {
        $pending = Join-Path $up 'pending.json'
        $journalPath = Join-Path $up 'transaction.json'
        $statePath = Join-Path $up 'installed-commit.txt'
        $previous = if (Test-Path -LiteralPath $statePath) { [IO.File]::ReadAllText($statePath).Trim() } else { '' }
        $journal = if (Test-Path -LiteralPath $journalPath) { Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json } else { $null }
        if ($journal -and $journal.status -eq 'preparing' -and $Action -ne 'Rollback') { throw 'Interrupted transaction: recover with offline Rollback first.' }
        if ($Action -eq 'Stage' -or $Action -eq 'Check') {
            $sha = Get-LatestCommit
            if ($sha -notmatch '^[a-fA-F0-9]{40}$') { throw 'Invalid commit SHA.' }
            if ($sha -eq $previous) { Write-Output ('Current: ' + $sha); return }
            if ($Action -eq 'Check') { Write-Output ('Available: ' + $sha); return }
            if (Test-Path -LiteralPath $pending) {
                $existing = Get-Content -LiteralPath $pending -Raw | ConvertFrom-Json
                if ($existing.sha -eq $sha) {
                    $existingStage = Assert-ChildPath $up $existing.directory
                    Assert-Inventory $existingStage $existing.files
                    Write-Output ('Already staged: ' + $sha)
                    return
                }
            }
            $download = Join-Path $up ('download-' + [guid]::NewGuid().ToString('N'))
            $null = New-Item -ItemType Directory -Path $download
            $source = Get-ResourceSnapshot $sha $download
            if (-not (Test-Path -LiteralPath (Join-Path $source 'fxmanifest.lua'))) { throw 'Archive resource missing.' }
            $null = Get-Inventory $source
            foreach ($rel in @('.env','bot/.env','bot/data','bot/logs','bot/node_modules','data','logs')) {
                if (Test-Path -LiteralPath (Join-Path $source $rel)) { throw ('Release contains protected runtime path: ' + $rel) }
            }
            $candidate = Join-Path $up ('stage-' + [guid]::NewGuid().ToString('N'))
            Copy-Item -LiteralPath $source -Destination $candidate -Recurse
            $manifest = @{ schema=1; sha=$sha; directory=$candidate; files=(Get-Inventory $candidate); migrationReviewRequired=$true }
            Write-AtomicText $pending ($manifest | ConvertTo-Json -Depth 6)
            Write-Output ('Staged ' + $sha + '; offline review/activation required. Active resource untouched.')
            return
        }
        Assert-Offline $OfflineConfirmed
        if ($Action -eq 'Rollback') {
            if (-not $journal -or $journal.status -notin @('preparing','activated')) { throw 'No recoverable transaction.' }
            $backup = Assert-ChildPath $up $journal.backup
            if (Test-Path -LiteralPath $backup) {
                if (-not (Test-Path -LiteralPath (Join-Path $backup 'fxmanifest.lua'))) { throw 'Invalid backup.' }
                if (Test-Path -LiteralPath $target) {
                    $restore = Join-Path $up ('restore-' + [guid]::NewGuid().ToString('N'))
                    Copy-CodeOnly $backup $restore
                    Copy-RuntimeData $target $restore
                    Assert-Offline $OfflineConfirmed
                    Move-Item -LiteralPath $target -Destination (Join-Path $up ('rollback-displaced-' + [guid]::NewGuid().ToString('N')))
                    Move-Item -LiteralPath $restore -Destination $target
                } else { Copy-Item -LiteralPath $backup -Destination $target -Recurse }
            } elseif ($journal.status -ne 'preparing' -or -not (Test-Path -LiteralPath $target)) { throw 'Backup missing.' }
            Write-AtomicText $statePath ([string]$journal.previousSha + [Environment]::NewLine)
            $journal.status = 'rolledBack'
            Write-AtomicText $journalPath ($journal | ConvertTo-Json -Depth 6)
            Write-Output 'Rollback complete. Reconcile displaced runtime data before restarting the bot.'
            return
        }
        if (-not (Test-Path -LiteralPath $pending)) { throw 'No staged release.' }
        $release = Get-Content -LiteralPath $pending -Raw | ConvertFrom-Json
        if ($release.sha -notmatch '^[a-fA-F0-9]{40}$' -or $ApprovedSha -ne $release.sha) { throw 'ExpectedSha must match the reviewed staged commit.' }
        $stage = Assert-ChildPath $up $release.directory
        Assert-Inventory $stage $release.files
        $candidate = Join-Path $up ('activate-' + [guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath $stage -Destination $candidate -Recurse
        Copy-RuntimeData $target $candidate
        $backup = Join-Path $up ('backup-' + [guid]::NewGuid().ToString('N'))
        $journal = @{ status='preparing'; backup=$backup; previousSha=$previous; sha=$release.sha }
        Write-AtomicText $journalPath ($journal | ConvertTo-Json -Depth 6)
        $oldMoved = $false
        $newMoved = $false
        try {
            Assert-Offline $OfflineConfirmed
            Move-Item -LiteralPath $target -Destination $backup
            $oldMoved = $true
            Move-Item -LiteralPath $candidate -Destination $target
            $newMoved = $true
            Write-AtomicText $statePath ($release.sha + [Environment]::NewLine)
            $journal.status = 'activated'
            Write-AtomicText $journalPath ($journal | ConvertTo-Json -Depth 6)
        } catch {
            if ($newMoved) { Move-Item -LiteralPath $target -Destination (Join-Path $up ('failed-' + [guid]::NewGuid().ToString('N'))) }
            if ($oldMoved) { Move-Item -LiteralPath $backup -Destination $target }
            Write-AtomicText $statePath ($previous + [Environment]::NewLine)
            $journal.status = 'rolledBack'
            Write-AtomicText $journalPath ($journal | ConvertTo-Json -Depth 6)
            throw
        }
        Write-Output ('Activated ' + $release.sha + '; backup: ' + $backup)
    } finally { $lock.Dispose() }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if ($CheckOnly) { $Mode = 'Check' }
        Invoke-LindenUpdate $ServerDataPath $Mode $ExpectedSha ([bool]$ServerStopped) |
            ForEach-Object {
                Write-Output $_
                $log = Join-Path ([IO.Path]::GetFullPath($ServerDataPath)) '.linden-updater/updater.log'
                [IO.File]::AppendAllText($log, [DateTime]::UtcNow.ToString('o') + ' ' + $_ + [Environment]::NewLine)
            }
    } catch {
        $failure = $_
        try {
            if ($ServerDataPath) {
                $logRoot = Join-Path ([IO.Path]::GetFullPath($ServerDataPath)) '.linden-updater'
                $logPath = Assert-ChildPath $logRoot (Join-Path $logRoot 'updater.log')
                if (Test-Path -LiteralPath $logRoot) {
                    [IO.File]::AppendAllText($logPath, [DateTime]::UtcNow.ToString('o') + ' ERROR: ' + $failure.Exception.Message + [Environment]::NewLine)
                }
            }
        } catch { Write-Warning 'Could not write updater error log.' }
        Write-Error $failure
        exit 1
    }
}

