[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CsdkRoot,

    [Parameter(Mandatory = $true)]
    [string]$GameRoot,

    [Parameter(Mandatory = $true)]
    [string]$OutputVpk,

    [ValidatePattern('^pak(?:0[1-9]|[1-9][0-9])_dir\.vpk$')]
    [string]$Slot = 'pak99_dir.vpk',

    [switch]$Install
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$csdkContentRoot = Join-Path $CsdkRoot 'content\citadel'
$csdkGameRoot = Join-Path $CsdkRoot 'game\citadel'
$resourceCompiler = Join-Path $CsdkRoot 'game\bin_cs2\win64\resourcecompiler.exe'
$vpkPacker = Join-Path $CsdkRoot 'game\bin\win64\CSDKCfgVPK.exe'
$outputParent = Split-Path -Parent $OutputVpk
$addonRoot = Join-Path $GameRoot 'game\citadel\addons'
$installedVpk = Join-Path $addonRoot $Slot

$resourceSpecs = @(
    @{ Source = (Join-Path $projectRoot 'src\panorama\layout\base_hud.xml'); Content = 'panorama\layout\base_hud.xml'; Compiled = 'panorama\layout\base_hud.vxml_c' },
    @{ Source = (Join-Path $projectRoot 'src\panorama\styles\dltoolkit.css'); Content = 'panorama\styles\dltoolkit.css'; Compiled = 'panorama\styles\dltoolkit.vcss_c' },
    @{ Source = (Join-Path $projectRoot 'src\panorama\scripts\dltoolkit_config.js'); Content = 'panorama\scripts\dltoolkit_config.js'; Compiled = 'panorama\scripts\dltoolkit_config.vjs_c' },
    @{ Source = (Join-Path $projectRoot 'src\panorama\scripts\dltoolkit_core.js'); Content = 'panorama\scripts\dltoolkit_core.js'; Compiled = 'panorama\scripts\dltoolkit_core.vjs_c' },
    @{ Source = (Join-Path $projectRoot 'src\panorama\scripts\modules\runes.js'); Content = 'panorama\scripts\modules\runes.js'; Compiled = 'panorama\scripts\modules\runes.vjs_c' },
    @{ Source = (Join-Path $projectRoot 'src\panorama\scripts\modules\party.js'); Content = 'panorama\scripts\modules\party.js'; Compiled = 'panorama\scripts\modules\party.vjs_c' },
    @{ Source = (Join-Path $projectRoot 'src\panorama\scripts\ui\settings.js'); Content = 'panorama\scripts\ui\settings.js'; Compiled = 'panorama\scripts\ui\settings.vjs_c' },
    @{ Source = (Join-Path $projectRoot 'src\sounds\dltk\rune_warning.wav'); Content = 'sounds\dltk\rune_warning.wav'; Compiled = 'sounds\dltk\rune_warning.vsnd_c' },
    @{ Source = (Join-Path $projectRoot 'src\soundevents\dltk.vsndevts'); Content = 'soundevents\dltk.vsndevts'; Compiled = 'soundevents\dltk.vsndevts_c' },
    @{ Source = (Join-Path $projectRoot 'src\soundevents\soundevents_addon.vsndevts'); Content = 'soundevents\soundevents_addon.vsndevts'; Compiled = 'soundevents\soundevents_addon.vsndevts_c' },
    @{ Source = (Join-Path $projectRoot 'src\resourcemanifests\addon_resources.vrman'); Content = 'resourcemanifests\addon_resources.vrman'; Compiled = 'resourcemanifests\addon_resources.vrman_c' }
)

foreach ($spec in $resourceSpecs) {
    if (-not (Test-Path -LiteralPath $spec.Source -PathType Leaf)) {
        throw "Missing source file: $($spec.Source)"
    }

    $destinationPath = Join-Path $csdkContentRoot $spec.Content
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destinationPath) | Out-Null
    Copy-Item -LiteralPath $spec.Source -Destination $destinationPath -Force
}

foreach ($toolPath in @($resourceCompiler, $vpkPacker)) {
    if (-not (Test-Path -LiteralPath $toolPath -PathType Leaf)) {
        throw "Missing build tool: $toolPath"
    }
}

$compileInputs = $resourceSpecs | ForEach-Object {
    Join-Path $csdkContentRoot $_.Content
}

& $resourceCompiler `
    -game $csdkGameRoot `
    -pc `
    -f `
    -nop4 `
    @compileInputs

if ($LASTEXITCODE -ne 0) {
    throw "ResourceCompiler failed with exit code $LASTEXITCODE"
}

$packRoot = Join-Path ([IO.Path]::GetTempPath()) ('dltk-pack-' + [Guid]::NewGuid().ToString('N'))

foreach ($spec in $resourceSpecs) {
    $compiledSource = Join-Path $csdkGameRoot $spec.Compiled
    if (-not (Test-Path -LiteralPath $compiledSource -PathType Leaf)) {
        throw "Compiled resource missing: $compiledSource"
    }

    $packDestination = Join-Path $packRoot $spec.Compiled
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $packDestination) | Out-Null
    Copy-Item -LiteralPath $compiledSource -Destination $packDestination -Force
}

if (Test-Path -LiteralPath $OutputVpk) {
    throw "Refusing to overwrite existing VPK: $OutputVpk"
}

New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
$packerProcess = Start-Process `
    -FilePath $vpkPacker `
    -ArgumentList @($packRoot, $OutputVpk) `
    -WorkingDirectory (Split-Path -Parent $vpkPacker) `
    -PassThru

$deadline = [DateTime]::UtcNow.AddMinutes(2)
while (-not (Test-Path -LiteralPath $OutputVpk -PathType Leaf)) {
    if ($packerProcess.HasExited -or [DateTime]::UtcNow -gt $deadline) {
        break
    }

    Start-Sleep -Milliseconds 250
}

if (-not (Test-Path -LiteralPath $OutputVpk -PathType Leaf)) {
    if (-not $packerProcess.HasExited) {
        Stop-Process -Id $packerProcess.Id -Force
    }

    throw "VPK packer did not produce: $OutputVpk"
}

if (-not $packerProcess.HasExited) {
    Stop-Process -Id $packerProcess.Id -Force
}

if ($Install) {
    New-Item -ItemType Directory -Force -Path $addonRoot | Out-Null

    if (Test-Path -LiteralPath $installedVpk -PathType Leaf) {
        throw "Refusing to overwrite existing installed VPK: $installedVpk"
    }

    Copy-Item -LiteralPath $OutputVpk -Destination $installedVpk
    Write-Output "Installed: $installedVpk"
}

Write-Output "Built: $OutputVpk"
