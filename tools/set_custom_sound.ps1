[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $projectRoot 'src\sounds\dltk\rune_warning.wav'
$source = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path

if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Input sound file was not found: $Path"
}

if ([IO.Path]::GetExtension($source).ToLowerInvariant() -ne '.wav') {
    throw 'Only WAV input is supported in v1. Use an uncompressed PCM WAV file.'
}

$bytes = [IO.File]::ReadAllBytes($source)
if ($bytes.Length -lt 44) {
    throw 'The WAV file is too small to contain a valid RIFF header.'
}

$riff = [Text.Encoding]::ASCII.GetString($bytes, 0, 4)
$wave = [Text.Encoding]::ASCII.GetString($bytes, 8, 4)
if ($riff -ne 'RIFF' -or $wave -ne 'WAVE') {
    throw 'The input must be a RIFF/WAVE file.'
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null

$destinationResolved = Resolve-Path -LiteralPath $destination -ErrorAction SilentlyContinue
if (-not $destinationResolved -or $source -ne $destinationResolved.Path) {
    Copy-Item -LiteralPath $source -Destination $destination -Force
}

$file = Get-Item -LiteralPath $destination
Write-Output "Canonical sound: $($file.FullName)"
Write-Output "Bytes: $($file.Length)"
Write-Output 'Ready for BuildOnly compilation. The game and installed VPK were not touched.'
