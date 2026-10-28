param([Parameter(Mandatory=$true)][string]$TestRoot)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../tools/update-linden.ps1')
$script:passed=0
function Assert($Condition,$Message) { if (-not $Condition) { throw $Message } }
function Rejects([scriptblock]$Run,$Pattern) {
    try { & $Run | Out-Null } catch { if ($_ -match $Pattern) { return }; throw }
    throw ('Expected failure: '+$Pattern)
}
function Case($Name,[scriptblock]$Run) { & $Run; $script:passed++; Write-Output ('PASS '+$Name) }
$script:fxRunning=$false
$script:nodeRunning=$false
function Get-Process($Name,$ErrorAction) {
    if (($Name -eq 'FXServer' -and $script:fxRunning) -or ($Name -eq 'node' -and $script:nodeRunning)) { return @{Id=99} }
}
$script:sha='a'*40
function Get-LatestCommit { return $script:sha }
$script:badArchive=$false
function Get-ResourceSnapshot($Sha,$Destination) {
    if ($script:badArchive) { throw 'download incomplete' }
    $source=Join-Path $Destination 'fixture'
    $null=New-Item -ItemType Directory -Path $source
    [IO.File]::WriteAllText((Join-Path $source 'fxmanifest.lua'), 'new resource')
    [IO.File]::WriteAllText((Join-Path $source 'client.lua'), 'new client')
    return $source
}
function Fixture {
    $data=Join-Path ([IO.Path]::GetFullPath($TestRoot)) ([guid]::NewGuid().ToString('N'))
    $target=Join-Path $data 'resources/[local]/linden_rp'
    $null=New-Item -ItemType Directory -Path (Join-Path $target 'bot/data') -Force
    [IO.File]::WriteAllText((Join-Path $target 'fxmanifest.lua'),'old resource')
    [IO.File]::WriteAllText((Join-Path $target 'bot/.env'),'test-secret-only')
    [IO.File]::WriteAllText((Join-Path $target 'bot/data/state.db'),'test-db')
    [IO.File]::WriteAllText((Join-Path $data 'server.cfg'),'test-cfg')
    return @{data=$data;target=$target;up=(Join-Path $data '.linden-updater')}
}
function Stage($f) { Invoke-LindenUpdate $f.data 'Stage' $null $false | Out-Null }
function Activate($f) { Invoke-LindenUpdate $f.data 'Activate' $script:sha $true | Out-Null }
Case 'staging is safe while FXServer is running and repeated staging is deduplicated' {
    $f=Fixture; $script:fxRunning=$true; Stage $f; Stage $f; $script:fxRunning=$false
    Assert ((Get-Content -LiteralPath (Join-Path $f.target 'fxmanifest.lua') -Raw) -eq 'old resource') 'Stage changed active code'
    Assert (-not (Test-Path -LiteralPath (Join-Path $f.up 'installed-commit.txt'))) 'Stage changed installed SHA'
    Assert (@(Get-ChildItem -LiteralPath $f.up -Directory | Where-Object Name -Like 'stage-*').Count -eq 1) 'Duplicate staging'
}
Case 'activation requires offline confirmation, no FXServer and no bot process' {
    $f=Fixture; Stage $f
    Rejects {Invoke-LindenUpdate $f.data Activate $script:sha $false} 'ServerStopped'
    $script:fxRunning=$true; Rejects {Activate $f} 'FXServer'; $script:fxRunning=$false
    $script:nodeRunning=$true; Rejects {Activate $f} 'Node'; $script:nodeRunning=$false
    Rejects {Invoke-LindenUpdate $f.data Activate ('b'*40) $true} 'ExpectedSha'
}
Case 'tampered stage refused before active files move' {
    $f=Fixture; Stage $f
    $release=Get-Content -LiteralPath (Join-Path $f.up 'pending.json') -Raw | ConvertFrom-Json
    [IO.File]::WriteAllText((Join-Path $release.directory 'client.lua'),'tampered')
    Rejects {Activate $f} 'hash mismatch'
    Assert ((Get-Content -LiteralPath (Join-Path $f.target 'fxmanifest.lua') -Raw) -eq 'old resource') 'Tamper changed target'
}
Case 'activation preserves runtime data, config and a full backup; rollback preserves latest runtime data' {
    $f=Fixture; Stage $f; Activate $f
    Assert ((Get-Content -LiteralPath (Join-Path $f.target 'fxmanifest.lua') -Raw) -eq 'new resource') 'New code not active'
    Assert ((Get-Content -LiteralPath (Join-Path $f.target 'bot/.env') -Raw) -eq 'test-secret-only') 'Environment lost'
    Assert ((Get-Content -LiteralPath (Join-Path $f.data 'server.cfg') -Raw) -eq 'test-cfg') 'Config modified'
    $j=Get-Content -LiteralPath (Join-Path $f.up 'transaction.json') -Raw | ConvertFrom-Json
    Assert ((Get-Content -LiteralPath (Join-Path $j.backup 'fxmanifest.lua') -Raw) -eq 'old resource') 'Backup missing'
    [IO.File]::WriteAllText((Join-Path $f.target 'bot/data/state.db'),'latest-db')
    Invoke-LindenUpdate $f.data Rollback $null $true | Out-Null
    Assert ((Get-Content -LiteralPath (Join-Path $f.target 'fxmanifest.lua') -Raw) -eq 'old resource') 'Rollback code wrong'
    Assert ((Get-Content -LiteralPath (Join-Path $f.target 'bot/data/state.db') -Raw) -eq 'latest-db') 'Rollback lost current data'
    Assert ((Get-Content -LiteralPath (Join-Path $j.backup 'bot/data/state.db') -Raw) -eq 'test-db') 'Backup mutated'
}
Case 'failed installed-SHA write rolls code and state back' {
    $f=Fixture; Stage $f
    $original=${function:Write-AtomicText}; $script:failState=$true
    function Write-AtomicText($Path,$Text) {
        if ($script:failState -and $Path.EndsWith('installed-commit.txt')) { $script:failState=$false; throw 'injected state write' }
        & $original $Path $Text
    }
    try { Rejects {Activate $f} 'injected state write' } finally { ${function:Write-AtomicText}=$original }
    Assert ((Get-Content -LiteralPath (Join-Path $f.target 'fxmanifest.lua') -Raw) -eq 'old resource') 'Automatic rollback failed'
    $j=Get-Content -LiteralPath (Join-Path $f.up 'transaction.json') -Raw | ConvertFrom-Json
    Assert ($j.status -eq 'rolledBack') 'Journal incorrect'
}
Case 'interrupted transaction with missing target recovers from backup' {
    $f=Fixture; Stage $f
    $backup=Join-Path $f.up 'backup-crash'
    Move-Item -LiteralPath $f.target -Destination $backup
    Write-AtomicText (Join-Path $f.up 'transaction.json') (@{status='preparing';backup=$backup;previousSha=('b'*40);sha=$script:sha} | ConvertTo-Json)
    Invoke-LindenUpdate $f.data Rollback $null $true | Out-Null
    Assert ((Get-Content -LiteralPath (Join-Path $f.target 'fxmanifest.lua') -Raw) -eq 'old resource') 'Crash recovery failed'
}
Case 'incomplete download and invalid remote SHA cannot change active files' {
    $f=Fixture; $script:badArchive=$true; Rejects {Stage $f} 'download incomplete'; $script:badArchive=$false
    Assert (-not (Test-Path -LiteralPath (Join-Path $f.up 'pending.json'))) 'Incomplete release published'
    $script:sha='invalid'; Rejects {Stage $f} 'Invalid commit'; $script:sha='a'*40
}
Case 'exclusive lock prevents overlapping transactions' {
    $f=Fixture; Stage $f
    $handle=[IO.File]::Open((Join-Path $f.up 'updater.lock'),'Open','ReadWrite','None')
    try { Rejects {Stage $f} 'used by another process|verwendet|being used|Zugriff|access|Open' } finally {$handle.Dispose()}
}
Case 'path escape is rejected' {
    $f=Fixture
    Rejects { Assert-ChildPath $f.data (Split-Path -Parent $f.data) } 'escapes'
}
Write-Output ('Updater tests passed: '+$script:passed)
