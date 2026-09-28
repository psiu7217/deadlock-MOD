[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GameRoot,
    [string]$BuiltVpk = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist\pak99_dir.vpk'),
    [string]$BackupRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'install-backups'),
    [ValidatePattern('^pak(?:0[1-9]|[1-9][0-9])_dir\.vpk$')]
    [string]$Slot = 'pak99_dir.vpk'
)

$ErrorActionPreference = 'Stop'

$addonRoot = Join-Path $GameRoot 'game\citadel\addons'
$installedVpk = Join-Path $addonRoot $Slot

$gameProcesses = @(Get-Process -Name @('deadlock', 'project8') -ErrorAction SilentlyContinue)
if ($gameProcesses.Count -gt 0) {
    throw 'Deadlock is running; no files were changed. Close the game and rerun this installer later.'
}

if (-not (Test-Path -LiteralPath $BuiltVpk -PathType Leaf)) {
    throw "Built VPK was not found: $BuiltVpk"
}

New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupName = '{0}-{1}.vpk' -f [IO.Path]::GetFileNameWithoutExtension($Slot), $timestamp
$backupVpk = Join-Path $BackupRoot $backupName

if (Test-Path -LiteralPath $installedVpk -PathType Leaf) {
    Copy-Item -LiteralPath $installedVpk -Destination $backupVpk
    Write-Output "Backup: $backupVpk"
} else {
    Write-Output "No existing installed VPK; backup skipped: $installedVpk"
}

New-Item -ItemType Directory -Force -Path $addonRoot | Out-Null
Copy-Item -LiteralPath $BuiltVpk -Destination $installedVpk -Force

$builtHash = (Get-FileHash -LiteralPath $BuiltVpk -Algorithm SHA256).Hash
$installedHash = (Get-FileHash -LiteralPath $installedVpk -Algorithm SHA256).Hash

if ($builtHash -ne $installedHash) {
    throw "Installed VPK hash mismatch: $installedVpk"
}

Write-Output "Installed: $installedVpk"
Write-Output "SHA256: $installedHash"
