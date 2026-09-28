$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")

Write-Host "Deadlock Personal Toolkit source tree" -ForegroundColor Cyan
Write-Host "Root: $Root"
Write-Host ""

Get-ChildItem -Path $Root -Recurse -File |
    ForEach-Object {
        $_.FullName.Substring($Root.Path.Length + 1)
    } |
    Sort-Object

Write-Host ""
Write-Host "Expected critical files:" -ForegroundColor Cyan

$Required = @(
    "src\panorama\layout\base_hud.xml",
    "src\panorama\styles\dltoolkit.css",
    "src\panorama\scripts\dltoolkit_config.js",
    "src\panorama\scripts\dltoolkit_core.js",
    "src\panorama\scripts\modules\party.js",
    "src\panorama\scripts\modules\runes.js",
    "src\panorama\scripts\ui\settings.js",
    "src\sounds\dltk\rune_warning.wav",
    "src\soundevents\dltk.vsndevts",
    "src\soundevents\soundevents_addon.vsndevts",
    "src\resourcemanifests\addon_resources.vrman",
    "tools\set_custom_sound.ps1"
)

$Missing = @()

foreach ($Relative in $Required) {
    $Path = Join-Path $Root $Relative
    if (Test-Path $Path) {
        Write-Host "  OK   $Relative" -ForegroundColor Green
    } else {
        Write-Host "  MISS $Relative" -ForegroundColor Red
        $Missing += $Relative
    }
}

if ($Missing.Count -gt 0) {
    throw "Toolkit source tree is incomplete."
}

Write-Host ""
Write-Host "Source tree check: PASS" -ForegroundColor Green
