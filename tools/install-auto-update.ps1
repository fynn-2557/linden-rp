# Run once as Administrator on the Windows server:
# powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install-auto-update.ps1 -ServerDataPath 'C:\...\txData\default.base'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ServerDataPath
)
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Open PowerShell as Administrator to register the updater task.'
}
$serverData = [IO.Path]::GetFullPath($ServerDataPath)
$resourceManifest = Join-Path $serverData 'resources\[local]\linden_rp\fxmanifest.lua'
if (-not (Test-Path -LiteralPath $resourceManifest -PathType Leaf)) {
    throw "Invalid server-data path. Not found: $resourceManifest"
}
$source = Join-Path $PSScriptRoot 'update-linden.ps1'
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw 'update-linden.ps1 must be in the same tools directory as this installer.'
}
$updateHome = Join-Path $serverData '.linden-updater'
New-Item -ItemType Directory -Path $updateHome -Force | Out-Null
$installed = Join-Path $updateHome 'update-linden.ps1'
Copy-Item -LiteralPath $source -Destination $installed -Force
$arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -ServerDataPath "{1}" -Mode Stage' -f $installed, $serverData
$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $arguments
# Task runs every 5 minutes, even without an interactive Windows login.
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -StartWhenAvailable
Register-ScheduledTask -TaskName 'LindenRP-AutoUpdate' -Action $action -Trigger $trigger -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Write-Host 'Task LindenRP-AutoUpdate installed (every 5 minutes).'
Write-Host ('Server-data: ' + $serverData)
Write-Host ('Log: ' + (Join-Path $updateHome 'updater.log'))
Write-Host 'The scheduled task only stages updates; restarts do NOT activate them.'
Write-Host 'Activation requires offline maintenance, reviewed ExpectedSha and -Mode Activate -ServerStopped.'
Write-Host 'Test immediately: schtasks /Run /TN "LindenRP-AutoUpdate"'

