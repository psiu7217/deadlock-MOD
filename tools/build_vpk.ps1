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

    [ValidateRange(10, 600)]
    [int]$PackerTimeoutSeconds = 120,

    [switch]$RuneOnly,

    [switch]$Install
)

$ErrorActionPreference = 'Stop'
$OutputVpk = [IO.Path]::GetFullPath($OutputVpk)

$projectRoot = Split-Path -Parent $PSScriptRoot
$csdkContentRoot = Join-Path $CsdkRoot 'content\citadel'
$csdkGameRoot = Join-Path $CsdkRoot 'game\citadel'
$installedGameContentRoot = Join-Path $GameRoot 'game\citadel'
$installedGamePak = Join-Path $installedGameContentRoot 'pak01_dir.vpk'
$generatedUiSoundevents = Join-Path $projectRoot 'build\generated\soundevents\ui.vsndevts'
$generatedPanoramaLayoutRoot = Join-Path $projectRoot 'build\generated\panorama\layout'
$generatedBaseHud = Join-Path $generatedPanoramaLayoutRoot 'base_hud.xml'
$generatedEscapeMenu = Join-Path $generatedPanoramaLayoutRoot 'hud_escape_menu.xml'
$stockPanoramaPatcher = Join-Path $PSScriptRoot 'patch_stock_panorama.ps1'
$runeWindowTemplate = Join-Path $projectRoot 'src\panorama\layout\dltk_window.xml'
$resourceCompiler = Join-Path $CsdkRoot 'game\bin_cs2\win64\resourcecompiler.exe'
$vpkPacker = Join-Path $CsdkRoot 'game\bin\win64\CSDKCfgVPK.exe'
$resourceInfo = Join-Path $CsdkRoot 'game\bin\win64\resourceinfo.exe'
$outputParent = Split-Path -Parent $OutputVpk
$addonRoot = Join-Path $GameRoot 'game\citadel\addons'
$installedVpk = Join-Path $addonRoot $Slot

function Get-TopLevelKv3Keys {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $keys = [System.Collections.Generic.List[string]]::new()
    $depth = 0
    $insideString = $false
    $escaped = $false

    foreach ($line in $Lines) {
        if ($depth -eq 1 -and $line -match '^\t([^=\s]+)\s*=\s*$') {
            $keys.Add($Matches[1])
        }

        foreach ($character in $line.ToCharArray()) {
            if ($insideString) {
                if ($escaped) {
                    $escaped = $false
                } elseif ($character -eq [char]92) {
                    $escaped = $true
                } elseif ($character -eq [char]34) {
                    $insideString = $false
                }
            } elseif ($character -eq [char]34) {
                $insideString = $true
            } elseif ($character -eq [char]123) {
                $depth++
            } elseif ($character -eq [char]125) {
                $depth--
            }
        }
    }

    return $keys.ToArray()
}

$baseHudSource = if ($RuneOnly) {
    $generatedBaseHud
} else {
    Join-Path $projectRoot 'src\panorama\layout\base_hud.xml'
}
$resourceSpecs = [System.Collections.Generic.List[object]]::new()
$resourceSpecs.Add(@{ Source = $baseHudSource; Content = 'panorama\layout\base_hud.xml'; Compiled = 'panorama\layout\base_hud.vxml_c' })
if ($RuneOnly) {
    $resourceSpecs.Add(@{ Source = $generatedEscapeMenu; Content = 'panorama\layout\hud_escape_menu.xml'; Compiled = 'panorama\layout\hud_escape_menu.vxml_c' })
}
$resourceSpecs.Add(@{ Source = (Join-Path $projectRoot 'src\panorama\styles\dltoolkit.css'); Content = 'panorama\styles\dltoolkit.css'; Compiled = 'panorama\styles\dltoolkit.vcss_c' })
$resourceSpecs.Add(@{ Source = (Join-Path $projectRoot 'src\panorama\scripts\dltoolkit_config.js'); Content = 'panorama\scripts\dltoolkit_config.js'; Compiled = 'panorama\scripts\dltoolkit_config.vjs_c' })
$resourceSpecs.Add(@{ Source = (Join-Path $projectRoot 'src\panorama\scripts\dltoolkit_core.js'); Content = 'panorama\scripts\dltoolkit_core.js'; Compiled = 'panorama\scripts\dltoolkit_core.vjs_c' })
$resourceSpecs.Add(@{ Source = (Join-Path $projectRoot 'src\panorama\scripts\modules\runes.js'); Content = 'panorama\scripts\modules\runes.js'; Compiled = 'panorama\scripts\modules\runes.vjs_c' })
$resourceSpecs.Add(@{ Source = (Join-Path $projectRoot 'src\panorama\scripts\ui\settings.js'); Content = 'panorama\scripts\ui\settings.js'; Compiled = 'panorama\scripts\ui\settings.vjs_c' })
if ($RuneOnly) {
    $resourceSpecs.Add(@{ Source = (Join-Path $projectRoot 'src\panorama\scripts\dltoolkit_bootstrap.js'); Content = 'panorama\scripts\dltoolkit_bootstrap.js'; Compiled = 'panorama\scripts\dltoolkit_bootstrap.vjs_c' })
    $resourceSpecs.Add(@{ Source = (Join-Path $projectRoot 'src\panorama\scripts\escape_bootstrap.js'); Content = 'panorama\scripts\escape_bootstrap.js'; Compiled = 'panorama\scripts\escape_bootstrap.vjs_c' })
}
$resourceSpecs.Add(@{ Source = (Join-Path $projectRoot 'src\sounds\dltk\rune_warning.wav'); Content = 'sounds\dltk\rune_warning.wav'; Compiled = 'sounds\dltk\rune_warning.vsnd_c' })
$resourceSpecs.Add(@{ Source = $generatedUiSoundevents; Content = 'soundevents\ui.vsndevts'; Compiled = 'soundevents\ui.vsndevts_c' })

if (-not $RuneOnly) {
    $partyResource = @{
        Source = (Join-Path $projectRoot 'src\panorama\scripts\modules\party.js')
        Content = 'panorama\scripts\modules\party.js'
        Compiled = 'panorama\scripts\modules\party.vjs_c'
    }
    $resourceSpecs.Add($partyResource)
}

foreach ($toolPath in @($resourceCompiler, $vpkPacker, $resourceInfo)) {
    if (-not (Test-Path -LiteralPath $toolPath -PathType Leaf)) {
        throw "Missing build tool: $toolPath"
    }
}

if (-not (Test-Path -LiteralPath $installedGamePak -PathType Leaf)) {
    throw "Current installed game pak is missing: $installedGamePak"
}

if ($RuneOnly) {
    if (-not (Test-Path -LiteralPath $stockPanoramaPatcher -PathType Leaf)) {
        throw "Missing stock Panorama patcher: $stockPanoramaPatcher"
    }
    & $stockPanoramaPatcher `
        -ResourceInfo $resourceInfo `
        -InstalledGamePak $installedGamePak `
        -GameContentRoot $installedGameContentRoot `
        -GeneratedLayoutRoot $generatedPanoramaLayoutRoot `
        -RuneWindowTemplate $runeWindowTemplate
}

$originalUiOutput = & $resourceInfo `
    -i "$installedGamePak/soundevents/ui.vsndevts_c" `
    -game $installedGameContentRoot `
    -b DATA `
    -baremode 2>&1
$originalUiExitCode = $LASTEXITCODE
if ($originalUiExitCode -ne 0) {
    throw "Failed to extract current ui.vsndevts_c DATA from '$installedGamePak'. resourceinfo exit code: $originalUiExitCode`n$($originalUiOutput -join [Environment]::NewLine)"
}

$originalUiLines = @($originalUiOutput | ForEach-Object { $_.ToString() })
if ($originalUiLines.Count -lt 3 -or $originalUiLines[0].Trim() -ne '{' -or $originalUiLines[-1].Trim() -ne '}') {
    throw 'resourceinfo did not return a complete KV3 dictionary for current ui.vsndevts_c.'
}

$originalUiEventNames = @(Get-TopLevelKv3Keys -Lines $originalUiLines)
if ($originalUiEventNames.Count -eq 0) {
    throw 'No top-level soundevents were found in the current ui.vsndevts_c.'
}
foreach ($requiredEvent in @('UI.PlayMenu.Activate', 'UI.MainMenu.Hover')) {
    if ($requiredEvent -notin $originalUiEventNames) {
        throw "Current ui.vsndevts_c is missing required original event '$requiredEvent'."
    }
}

if ('DLTK.Rune.Warning' -in $originalUiEventNames) {
    throw 'DLTK.Rune.Warning already exists in current ui.vsndevts_c; refusing to add a duplicate.'
}

$generatedDirectory = Split-Path -Parent $generatedUiSoundevents
New-Item -ItemType Directory -Force -Path $generatedDirectory | Out-Null
$customEventLines = @(
    '',
    "`tDLTK.Rune.Warning =",
    "`t{",
    "`t`tbase = `"Base.UI`"",
    "`t`tvolume = 22.0",
    "`t`tpitch = 1.0",
    "`t`tvsnd_files = `"sounds/dltk/rune_warning.vsnd`"",
    "`t`tvsnd_duration = 1.130658",
    "`t}"
)
$kv3Header = '<!-- kv3 encoding:text:version{e21c7f3c-8a33-41c5-9977-a76d3a32aa0d} format:generic:version{7412167c-06e9-4698-aff2-e63eb59037e7} -->'
if ($kv3Header -notmatch '^<!-- kv3 encoding:text:version\{[0-9a-f-]+\} format:generic:version\{[0-9a-f-]+\} -->$') {
    throw 'The configured KV3 generic encoding header is invalid.'
}

$patchedUiLines = @($kv3Header) + @($originalUiLines[0..($originalUiLines.Count - 2)]) + $customEventLines + @($originalUiLines[-1])
$patchedUiEventNames = @(Get-TopLevelKv3Keys -Lines $patchedUiLines)
if ($patchedUiEventNames.Count -ne ($originalUiEventNames.Count + 1)) {
    throw "Patched event count mismatch: original=$($originalUiEventNames.Count), patched=$($patchedUiEventNames.Count)."
}

$missingOriginalEvents = @($originalUiEventNames | Where-Object { $_ -notin $patchedUiEventNames })
if ($missingOriginalEvents.Count -gt 0) {
    throw "Generated ui.vsndevts lost original event(s): $($missingOriginalEvents -join ', ')"
}

if ('DLTK.Rune.Warning' -notin $patchedUiEventNames) {
    throw 'Generated ui.vsndevts does not contain DLTK.Rune.Warning.'
}

[IO.File]::WriteAllLines(
    $generatedUiSoundevents,
    [string[]]$patchedUiLines,
    [System.Text.UTF8Encoding]::new($false)
)
Write-Output "Current ui.vsndevts extracted: $($originalUiEventNames.Count) events"
Write-Output "Generated ui.vsndevts: $($patchedUiEventNames.Count) events (original + 1)"

$baseUiOutput = & $resourceInfo `
    -i "$installedGamePak/soundevents/base/ui.vsndevts_c" `
    -game $installedGameContentRoot `
    -b DATA `
    -baremode 2>&1
$baseUiExitCode = $LASTEXITCODE
if ($baseUiExitCode -ne 0) {
    throw "Failed to inspect current soundevents/base/ui.vsndevts_c. resourceinfo exit code: $baseUiExitCode`n$($baseUiOutput -join [Environment]::NewLine)"
}
$baseUiLines = @($baseUiOutput | ForEach-Object { $_.ToString() })
$baseUiEventNames = @(Get-TopLevelKv3Keys -Lines $baseUiLines)
if ('Base.UI' -notin $baseUiEventNames) {
    throw 'Current soundevents/base/ui.vsndevts_c does not define Base.UI.'
}
$baseUiText = $baseUiLines -join [Environment]::NewLine
$baseUiMatch = [regex]::Match($baseUiText, '(?ms)^\tBase\.UI\s*=\s*\{\s*(?<body>.*?)^\t\}')
$baseUiBody = if ($baseUiMatch.Success) { $baseUiMatch.Groups['body'].Value } else { '' }
if ($baseUiBody -notmatch 'type\s*=\s*"citadel_ui_panner"' -or
    $baseUiBody -notmatch 'mixer_mixgroup\s*=\s*"UI"') {
    throw 'Current Base.UI is present but is not compatible with the proven DLTK UI sound event base.'
}
Write-Output 'Current Base.UI compatibility: PASS (citadel_ui_panner, UI mixgroup)'

foreach ($spec in $resourceSpecs) {
    if (-not (Test-Path -LiteralPath $spec.Source -PathType Leaf)) {
        throw "Missing source file: $($spec.Source)"
    }

    $destinationPath = Join-Path $csdkContentRoot $spec.Content
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destinationPath) | Out-Null
    Copy-Item -LiteralPath $spec.Source -Destination $destinationPath -Force
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
$packerArgumentLine = '"{0}" "{1}"' -f $packRoot, $OutputVpk
$packerProcess = Start-Process `
    -FilePath $vpkPacker `
    -ArgumentList $packerArgumentLine `
    -WorkingDirectory (Split-Path -Parent $vpkPacker) `
    -WindowStyle Hidden `
    -PassThru

$packDeadline = [DateTime]::UtcNow.AddSeconds($PackerTimeoutSeconds)
$previousLength = -1L
$previousWriteTime = [DateTime]::MinValue
$stableSamples = 0
$stableSince = $null
$vpkStabilized = $false

while ([DateTime]::UtcNow -lt $packDeadline) {
    if (Test-Path -LiteralPath $OutputVpk -PathType Leaf) {
        $outputFile = Get-Item -LiteralPath $OutputVpk
        if ($outputFile.Length -gt 0 -and
            $outputFile.Length -eq $previousLength -and
            $outputFile.LastWriteTimeUtc -eq $previousWriteTime) {
            $stableSamples++
            if ($null -eq $stableSince) {
                $stableSince = [DateTime]::UtcNow
            }
        } else {
            $stableSamples = 0
            $stableSince = $null
        }

        $previousLength = $outputFile.Length
        $previousWriteTime = $outputFile.LastWriteTimeUtc

        if ($stableSamples -ge 4 -and
            $null -ne $stableSince -and
            ([DateTime]::UtcNow - $stableSince).TotalSeconds -ge 2) {
            $stream = $null
            try {
                $stream = [IO.File]::Open(
                    $OutputVpk,
                    [IO.FileMode]::Open,
                    [IO.FileAccess]::Read,
                    [IO.FileShare]::Read
                )
                if ($stream.Length -gt 0) {
                    $signatureBytes = New-Object byte[] 4
                    $signatureRead = $stream.Read($signatureBytes, 0, $signatureBytes.Length)
                    if ($signatureRead -eq 4) {
                        $signature = [BitConverter]::ToUInt32($signatureBytes, 0)
                        if ($signature -ne 0x55AA1234) {
                            throw ('Invalid VPK signature 0x{0:X8}: {1}' -f $signature, $OutputVpk)
                        }
                        $vpkStabilized = $true
                    }
                }
            } catch [IO.IOException] {
                # The GUI packer may still hold the output while its success dialog is open.
                $vpkStabilized = $false
            } finally {
                if ($null -ne $stream) {
                    $stream.Dispose()
                }
            }

            if ($vpkStabilized) {
                break
            }
        }
    }

    Start-Sleep -Milliseconds 500
}

if (-not $vpkStabilized) {
    $packerProcess.Refresh()
    $processState = if ($packerProcess.HasExited) { "exited with code $($packerProcess.ExitCode)" } else { 'still running' }
    $packerProcess.Dispose()
    throw "VPK output did not become stable, readable, and structurally valid within $PackerTimeoutSeconds seconds; packer is $processState."
}

Write-Output "VPK output stabilized and header verified: $OutputVpk"

foreach ($spec in $resourceSpecs) {
    $compiledPath = $spec.Compiled.Replace('\', '/')
    $vpkMemberPath = "$OutputVpk/$compiledPath"
    $inspectionOutput = & $resourceInfo -i $vpkMemberPath -game $csdkGameRoot 2>&1
    $inspectionExitCode = $LASTEXITCODE
    $inspectionText = $inspectionOutput -join [Environment]::NewLine

    if ($inspectionExitCode -ne 0 -or $inspectionText -notmatch [regex]::Escape($compiledPath)) {
        throw "VPK content verification failed for '$compiledPath'. resourceinfo exit code: $inspectionExitCode`n$inspectionText"
    }
}

if ($RuneOnly) {
    $escapeMember = "$OutputVpk/panorama/layout/hud_escape_menu.vxml_c"
    $escapeAstOutput = & $resourceInfo `
        -i $escapeMember `
        -game $csdkGameRoot `
        -b LaCo `
        -baremode 2>&1
    $escapeAstExitCode = $LASTEXITCODE
    $escapeAstText = @($escapeAstOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    if ($escapeAstExitCode -ne 0) {
        throw "Could not inspect packaged hud_escape_menu.vxml_c. resourceinfo exit code: $escapeAstExitCode`n$escapeAstText"
    }
    if ([regex]::Matches($escapeAstText, 'name\s*=\s*"DLTKEscapeLauncher"').Count -ne 1 -or
        $escapeAstText -notmatch 'name\s*=\s*"\$\.DLTK\.UI\.open\(\);"') {
        throw 'Packaged stock Escape layout is missing exactly one DLTK launcher or its same-context UI open handler.'
    }
    $launcherPosition = $escapeAstText.IndexOf('name = "DLTKEscapeLauncher"', [StringComparison]::Ordinal)
    $quitPosition = $escapeAstText.IndexOf('name = "quit"', [StringComparison]::Ordinal)
    if ($launcherPosition -lt 0 -or $quitPosition -lt 0 -or $launcherPosition -ge $quitPosition) {
        throw 'Packaged DLTK Escape launcher is not serialized before the stock #quit control.'
    }
    foreach ($requiredString in @(
        'name = "PlayerFeedback"',
        'name = "settings"',
        'CitadelQuitConfirm()',
        'CitadelSettings()',
        'DLTKRuneEnabledButton',
        'DLTKGameTimeValue',
        'DLTKNextRuneValue',
        'DLTKNextWarningValue'
    )) {
        if ($escapeAstText -notmatch [regex]::Escape($requiredString)) {
            throw "Packaged Escape/Rune UI is missing required current-stock/control string '$requiredString'."
        }
    }

    $baseHudMember = "$OutputVpk/panorama/layout/base_hud.vxml_c"
    $baseHudAstOutput = & $resourceInfo `
        -i $baseHudMember `
        -game $csdkGameRoot `
        -b LaCo `
        -baremode 2>&1
    $baseHudAstExitCode = $LASTEXITCODE
    $baseHudAstText = @($baseHudAstOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    if ($baseHudAstExitCode -ne 0 -or
        $baseHudAstText -notmatch 'WindowRoot' -or
        $baseHudAstText -notmatch 'name = "Hud"' -or
        $baseHudAstText -notmatch 'dltoolkit_bootstrap') {
        throw "Packaged base_hud.vxml_c is not the current stock base with the DLTK bootstrap probe. resourceinfo exit code: $baseHudAstExitCode`n$baseHudAstText"
    }

    $initializationChecks = @(
        @{ Member = 'panorama/scripts/dltoolkit_bootstrap.vjs_c'; Marker = '[DLTK][Bootstrap] base HUD script loaded' },
        @{ Member = 'panorama/scripts/dltoolkit_core.vjs_c'; Marker = '[DLTK][Core] initialized' },
        @{ Member = 'panorama/scripts/escape_bootstrap.vjs_c'; Marker = '[DLTK][ESC] escape integration loaded' },
        @{ Member = 'panorama/scripts/ui/settings.vjs_c'; Marker = '[DLTK][Runes] UI initialized' }
    )
    foreach ($check in $initializationChecks) {
        $scriptOutput = & $resourceInfo `
            -i "$OutputVpk/$($check.Member)" `
            -game $csdkGameRoot `
            -b DATA `
            -baremode 2>&1
        $scriptExitCode = $LASTEXITCODE
        $scriptText = @($scriptOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
        if ($scriptExitCode -ne 0 -or $scriptText.IndexOf($check.Marker, [StringComparison]::Ordinal) -lt 0) {
            throw "Packaged initialization marker '$($check.Marker)' was not found in '$($check.Member)' (resourceinfo exit $scriptExitCode).`n$scriptText"
        }
    }

    $partyMember = "$OutputVpk/panorama/scripts/modules/party.vjs_c"
    $partyOutput = & $resourceInfo -i $partyMember -game $csdkGameRoot 2>&1
    $partyExitCode = $LASTEXITCODE
    $partyText = @($partyOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    if ($partyExitCode -eq 0 -or $partyText -notmatch 'No input file\(s\) found') {
        throw "Rune-only VPK must not contain Party module; absence check failed. resourceinfo exit code: $partyExitCode`n$partyText"
    }
    Write-Output 'Packaged stock Escape override: PASS (native IDs/handlers retained; DLTK launcher before #quit; same-context UI)'
    Write-Output 'Packaged base HUD probe: PASS (current stock layout plus one bootstrap include)'
    Write-Output 'Packaged initialization logs: PASS (base HUD, core, Escape, Rune UI)'
    Write-Output 'Rune-only Party exclusion: PASS'
}

$compiledUiVpkMember = "$OutputVpk/soundevents/ui.vsndevts_c"
$compiledUiOutput = & $resourceInfo `
    -i $compiledUiVpkMember `
    -game $csdkGameRoot `
    -b DATA `
    -baremode 2>&1
$compiledUiExitCode = $LASTEXITCODE
if ($compiledUiExitCode -ne 0) {
    throw "Failed to inspect compiled ui.vsndevts_c in VPK. resourceinfo exit code: $compiledUiExitCode`n$($compiledUiOutput -join [Environment]::NewLine)"
}

$compiledUiLines = @($compiledUiOutput | ForEach-Object { $_.ToString() })
$compiledUiEventNames = @(Get-TopLevelKv3Keys -Lines $compiledUiLines)
if ($compiledUiEventNames.Count -ne ($originalUiEventNames.Count + 1)) {
    throw "Compiled event count mismatch: original=$($originalUiEventNames.Count), compiled=$($compiledUiEventNames.Count)."
}

$missingCompiledOriginalEvents = @($originalUiEventNames | Where-Object { $_ -notin $compiledUiEventNames })
if ($missingCompiledOriginalEvents.Count -gt 0) {
    throw "Compiled ui.vsndevts lost original event(s): $($missingCompiledOriginalEvents -join ', ')"
}

foreach ($requiredEvent in @('UI.PlayMenu.Activate', 'UI.MainMenu.Hover', 'DLTK.Rune.Warning')) {
    if ($requiredEvent -notin $compiledUiEventNames) {
        throw "Compiled ui.vsndevts is missing required event '$requiredEvent'."
    }
}

$compiledUiText = $compiledUiLines -join [Environment]::NewLine
$customEventMatch = [regex]::Match($compiledUiText, '(?ms)^\tDLTK\.Rune\.Warning\s*=\s*\{\s*(?<body>.*?)^\t\}')
$customEventBody = if ($customEventMatch.Success) { $customEventMatch.Groups['body'].Value } else { '' }
if ($customEventBody -notmatch 'base\s*=\s*"Base\.UI"' -or
    $customEventBody -notmatch 'volume\s*=\s*22\.0+' -or
    $customEventBody -notmatch 'pitch\s*=\s*1\.0+' -or
    $customEventBody -notmatch 'vsnd_files\s*=\s*"sounds/dltk/rune_warning\.vsnd"') {
    throw 'Compiled DLTK.Rune.Warning does not match the required Base.UI, volume 22.0, pitch 1.0, and WAV mapping.'
}

foreach ($forbiddenMember in @('soundevents/soundevents_addon.vsndevts_c', 'resourcemanifests/addon_resources.vrman_c')) {
    $forbiddenOutput = & $resourceInfo -i "$OutputVpk/$forbiddenMember" -game $csdkGameRoot 2>&1
    $forbiddenExitCode = $LASTEXITCODE
    $forbiddenText = $forbiddenOutput -join [Environment]::NewLine
    if ($forbiddenExitCode -eq 0) {
        throw "Unexpected diagnostic-only member in VPK: $forbiddenMember"
    }

    if ($forbiddenText -notmatch 'No input file\(s\) found') {
        throw "Could not verify diagnostic-only member absence '$forbiddenMember'. resourceinfo exit code: $forbiddenExitCode`n$forbiddenText"
    }
}

Write-Output "Compiled ui.vsndevts inspection: PASS ($($compiledUiEventNames.Count) events; original + 1)"

# CSDKCfgVPK can display a success dialog and intentionally remain alive after packing.
# Do not close it until the VPK has passed every structural and content validation above.
$packerProcess.Refresh()
if (-not $packerProcess.HasExited) {
    $null = $packerProcess.CloseMainWindow()
    if (-not $packerProcess.WaitForExit(3000)) {
        $packerProcess.Refresh()
        if (-not $packerProcess.HasExited) {
            if ($packerProcess.ProcessName -ne [IO.Path]::GetFileNameWithoutExtension($vpkPacker)) {
                $packerProcess.Dispose()
                throw 'Refusing to stop the packer: process identity no longer matches CSDKCfgVPK.'
            }

            Stop-Process -InputObject $packerProcess -Force
            if (-not $packerProcess.WaitForExit(5000)) {
                $packerProcess.Dispose()
                throw 'Validated VPK, but CSDKCfgVPK did not exit after targeted cleanup.'
            }
        }
    }
}

$packerExitCode = if ($packerProcess.HasExited) { $packerProcess.ExitCode } else { $null }
$packerProcess.Dispose()
Write-Output "VPK packer cleanup after successful validation: PASS (exit code: $packerExitCode)"

if ($Install) {
    New-Item -ItemType Directory -Force -Path $addonRoot | Out-Null

    if (Test-Path -LiteralPath $installedVpk -PathType Leaf) {
        throw "Refusing to overwrite existing installed VPK: $installedVpk"
    }

    Copy-Item -LiteralPath $OutputVpk -Destination $installedVpk
    Write-Output "Installed: $installedVpk"
}

Write-Output "Built: $OutputVpk"
