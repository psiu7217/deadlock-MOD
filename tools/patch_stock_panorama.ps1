[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceInfo,

    [Parameter(Mandatory = $true)]
    [string]$InstalledGamePak,

    [Parameter(Mandatory = $true)]
    [string]$GameContentRoot,

    [Parameter(Mandatory = $true)]
    [string]$GeneratedLayoutRoot,

    [Parameter(Mandatory = $true)]
    [string]$RuneWindowTemplate
)

$ErrorActionPreference = 'Stop'

function Read-Kv3Value {
    $token = $script:Kv3Tokens[$script:Kv3Position]
    $script:Kv3Position++

    if ($token -eq '{') {
        $dictionary = [ordered]@{}
        while ($script:Kv3Position -lt $script:Kv3Tokens.Count -and
            $script:Kv3Tokens[$script:Kv3Position] -ne '}') {
            $keyToken = $script:Kv3Tokens[$script:Kv3Position]
            $script:Kv3Position++
            $key = if ($keyToken.StartsWith('"')) {
                [string](ConvertFrom-Json -InputObject $keyToken -ErrorAction Stop)
            } else {
                $keyToken
            }

            if ($script:Kv3Tokens[$script:Kv3Position] -ne '=') {
                throw "Expected '=' after KV3 key '$key'."
            }
            $script:Kv3Position++
            $dictionary[$key] = Read-Kv3Value

            if ($script:Kv3Position -lt $script:Kv3Tokens.Count -and
                $script:Kv3Tokens[$script:Kv3Position] -eq ',') {
                $script:Kv3Position++
            }
        }

        if ($script:Kv3Position -ge $script:Kv3Tokens.Count -or
            $script:Kv3Tokens[$script:Kv3Position] -ne '}') {
            throw 'Unterminated KV3 object.'
        }
        $script:Kv3Position++
        return $dictionary
    }

    if ($token -eq '[') {
        $values = [System.Collections.Generic.List[object]]::new()
        while ($script:Kv3Position -lt $script:Kv3Tokens.Count -and
            $script:Kv3Tokens[$script:Kv3Position] -ne ']') {
            $values.Add((Read-Kv3Value))
            if ($script:Kv3Position -lt $script:Kv3Tokens.Count -and
                $script:Kv3Tokens[$script:Kv3Position] -eq ',') {
                $script:Kv3Position++
            }
        }

        if ($script:Kv3Position -ge $script:Kv3Tokens.Count -or
            $script:Kv3Tokens[$script:Kv3Position] -ne ']') {
            throw 'Unterminated KV3 array.'
        }
        $script:Kv3Position++
        return ,$values.ToArray()
    }

    if ($token.StartsWith('"')) {
        return [string](ConvertFrom-Json -InputObject $token -ErrorAction Stop)
    }

    if ($token -eq 'true') { return $true }
    if ($token -eq 'false') { return $false }
    if ($token -eq 'null') { return $null }
    if ($token -match '^-?\d+$') { return [long]::Parse($token, [Globalization.CultureInfo]::InvariantCulture) }
    if ($token -match '^-?(?:\d+\.\d*|\d*\.\d+)$') {
        return [double]::Parse($token, [Globalization.CultureInfo]::InvariantCulture)
    }
    return $token
}

function ConvertFrom-Kv3AstText {
    param([Parameter(Mandatory = $true)][string]$Text)

    $pattern = '"(?:\\.|[^"\\])*"|[{}\[\]=,]|[A-Za-z_][A-Za-z0-9_.-]*|-?\d+(?:\.\d+)?'
    $matches = [regex]::Matches($Text, $pattern)
    $unmatched = [regex]::Replace($Text, $pattern, '').Trim()
    if ($unmatched.Length -gt 0) {
        throw "Unsupported characters remain in resourceinfo KV3 output: $($unmatched.Substring(0, [Math]::Min(100, $unmatched.Length)))"
    }

    $script:Kv3Tokens = [System.Collections.Generic.List[string]]::new()
    foreach ($match in $matches) {
        $script:Kv3Tokens.Add($match.Value)
    }
    $script:Kv3Position = 0
    $value = Read-Kv3Value
    if ($script:Kv3Position -ne $script:Kv3Tokens.Count) {
        throw "KV3 parser stopped at token $($script:Kv3Position) of $($script:Kv3Tokens.Count)."
    }
    return $value
}

function Convert-AstNodeToXml {
    param(
        [Parameter(Mandatory = $true)]$Node,
        [Parameter(Mandatory = $true)][xml]$Document
    )

    $type = [string]$Node['eType']
    switch ($type) {
        'ROOT' {
            $element = $Document.CreateElement('root')
            foreach ($childNode in $Node['vecChildren']) {
                [void]$element.AppendChild((Convert-AstNodeToXml -Node $childNode -Document $Document))
            }
            return $element
        }
        'STYLES' {
            $element = $Document.CreateElement('styles')
            $children = if ($Node.Contains('vecChildren')) {
                @($Node['vecChildren'])
            } elseif ($Node.Contains('child')) {
                @($Node['child'])
            } else {
                @()
            }
            foreach ($childNode in $children) {
                [void]$element.AppendChild((Convert-AstNodeToXml -Node $childNode -Document $Document))
            }
            return $element
        }
        'INCLUDE' {
            $reference = $Node['child']
            if ([string]$reference['eType'] -ne 'REFERENCE_COMPILED') {
                throw 'Encountered a Panorama include without a compiled resource reference.'
            }
            $resourceName = [string]$reference['name']
            if ($resourceName -match '\.(vcss|vjs|vxml|vsnd|vsndevts)$') {
                $resourceName += '_c'
            }
            $element = $Document.CreateElement('include')
            $element.SetAttribute('src', "s2r://$resourceName")
            return $element
        }
        'PANEL' {
            $elementName = [string]$Node['name']
            if ($elementName -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
                throw "Unexpected Panorama panel type '$elementName'."
            }
            $element = $Document.CreateElement($elementName)
            $children = if ($Node.Contains('vecChildren')) {
                @($Node['vecChildren'])
            } elseif ($Node.Contains('child')) {
                @($Node['child'])
            } else {
                @()
            }

            foreach ($childNode in $children) {
                $childType = [string]$childNode['eType']
                if ($childType -eq 'PANEL_ATTRIBUTE') {
                    $attributeName = [string]$childNode['name']
                    $attributeValue = [string]$childNode['child']['name']
                    $element.SetAttribute($attributeName, $attributeValue)
                } elseif ($childType -eq 'PANEL') {
                    [void]$element.AppendChild((Convert-AstNodeToXml -Node $childNode -Document $Document))
                } else {
                    throw "Unexpected '$childType' child in Panorama panel '$elementName'."
                }
            }
            return $element
        }
        default {
            throw "Unsupported Panorama AST node type '$type'."
        }
    }
}

function Get-StockAstDocument {
    param([Parameter(Mandatory = $true)][string]$ResourcePath)

    $output = @(& $ResourceInfo `
        -i "$InstalledGamePak/$ResourcePath" `
        -game $GameContentRoot `
        -b LaCo `
        -baremode 2>&1)
    $exitCode = $LASTEXITCODE
    $text = (@($output | ForEach-Object { $_.ToString() })) -join [Environment]::NewLine
    if ($exitCode -ne 0 -or [string]::IsNullOrWhiteSpace($text)) {
        throw "Could not decompile stock '$ResourcePath' from current pak01_dir.vpk (exit $exitCode).`n$text"
    }

    $parsed = ConvertFrom-Kv3AstText -Text $text
    if (-not $parsed.Contains('m_AST') -or -not $parsed['m_AST'].Contains('m_pRoot')) {
        throw "resourceinfo result for '$ResourcePath' has no m_AST.m_pRoot."
    }

    $document = [xml]::new()
    $root = Convert-AstNodeToXml -Node $parsed['m_AST']['m_pRoot'] -Document $document
    [void]$document.AppendChild($root)
    return $document
}

function Get-Section {
    param(
        [Parameter(Mandatory = $true)][xml]$Document,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $root = $Document.DocumentElement
    $section = $root.SelectSingleNode("./$Name")
    if ($null -eq $section) {
        $section = $Document.CreateElement($Name)
        $styles = $root.SelectSingleNode('./styles')
        if ($Name -eq 'scripts' -and $null -ne $styles) {
            [void]$root.InsertAfter($section, $styles)
        } elseif ($root.FirstChild) {
            [void]$root.InsertBefore($section, $root.FirstChild)
        } else {
            [void]$root.AppendChild($section)
        }
    }
    return $section
}

function Add-IncludeNodes {
    param(
        [Parameter(Mandatory = $true)][xml]$TargetDocument,
        [Parameter(Mandatory = $true)][xml]$TemplateDocument,
        [Parameter(Mandatory = $true)][string]$SectionName
    )

    $targetSection = Get-Section -Document $TargetDocument -Name $SectionName
    foreach ($include in $TemplateDocument.SelectNodes("/root/$SectionName/include")) {
        $source = $include.GetAttribute('src')
        $existing = $targetSection.SelectSingleNode("./include[@src='$source']")
        if ($null -eq $existing) {
            [void]$targetSection.AppendChild($TargetDocument.ImportNode($include, $true))
        }
    }
}

function Get-IntegritySignatureCounts {
    param([Parameter(Mandatory = $true)][xml]$Document)

    $counts = @{}
    foreach ($element in $Document.SelectNodes('//*')) {
        $handlers = @(
            $element.Attributes |
                Where-Object { $_.Name -match '^on' } |
                ForEach-Object { "$($_.Name)=$($_.Value)" } |
                Sort-Object
        )
        $id = $element.GetAttribute('id')
        if ($id.Length -eq 0 -and $handlers.Count -eq 0) {
            continue
        }
        $signature = '{0}|{1}|{2}|{3}' -f $element.LocalName, $id, $element.GetAttribute('class'), ($handlers -join ';')
        if (-not $counts.ContainsKey($signature)) {
            $counts[$signature] = 0
        }
        $counts[$signature]++
    }
    return $counts
}

function Save-XmlDocument {
    param(
        [Parameter(Mandatory = $true)][xml]$Document,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $settings = [Xml.XmlWriterSettings]::new()
    $settings.Encoding = [Text.UTF8Encoding]::new($false)
    $settings.Indent = $true
    $settings.NewLineChars = "`n"
    $settings.OmitXmlDeclaration = $true
    $writer = [Xml.XmlWriter]::Create($Path, $settings)
    try {
        $Document.Save($writer)
    } finally {
        $writer.Dispose()
    }
}

foreach ($path in @($ResourceInfo, $InstalledGamePak, $RuneWindowTemplate)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required stock UI input is missing: $path"
    }
}

$template = [xml]::new()
$template.PreserveWhitespace = $false
$template.Load($RuneWindowTemplate)
$templatePanels = @($template.SelectNodes('/root/Panel[@id="DLToolkitOverlay"]'))
if ($templatePanels.Count -ne 1) {
    throw "Rune window template must contain exactly one root Panel#DLToolkitOverlay: $RuneWindowTemplate"
}
$templatePanel = $templatePanels[0]

$generatedBaseHud = Get-StockAstDocument -ResourcePath 'panorama/layout/base_hud.vxml_c'
$stockBaseForCompare = [xml]::new()
$stockBaseForCompare.LoadXml($generatedBaseHud.OuterXml)
$baseRoot = $generatedBaseHud.DocumentElement
$basePanel = $baseRoot.SelectSingleNode('./Panel[@class="WindowRoot"]')
if ($null -eq $basePanel -or $null -eq $basePanel.SelectSingleNode('.//CitadelHud[@id="Hud"]')) {
    throw 'Current stock base_hud AST did not contain WindowRoot with CitadelHud#Hud.'
}
if ($null -eq $baseRoot.SelectSingleNode('./styles/include[@src="s2r://panorama/styles/base.vcss_c"]')) {
    throw 'Current stock base_hud AST did not retain its base.vcss include.'
}
$baseScripts = Get-Section -Document $generatedBaseHud -Name 'scripts'
$baseBootstrapPath = 's2r://panorama/scripts/dltoolkit_bootstrap.vjs_c'
if ($null -eq $baseScripts.SelectSingleNode("./include[@src='$baseBootstrapPath']")) {
    $include = $generatedBaseHud.CreateElement('include')
    $include.SetAttribute('src', $baseBootstrapPath)
    [void]$baseScripts.AppendChild($include)
}
$stockBaseSignatures = Get-IntegritySignatureCounts -Document $stockBaseForCompare
$generatedBaseSignatures = Get-IntegritySignatureCounts -Document $generatedBaseHud
foreach ($signature in $stockBaseSignatures.Keys) {
    if (-not $generatedBaseSignatures.ContainsKey($signature) -or
        $generatedBaseSignatures[$signature] -lt $stockBaseSignatures[$signature]) {
        throw "Generated base_hud did not retain original panel/handler signature: $signature"
    }
}

$stockEscape = Get-StockAstDocument -ResourcePath 'panorama/layout/hud_escape_menu.vxml_c'
$stockEscapeRoot = $stockEscape.DocumentElement
$nativeRoot = $stockEscapeRoot.SelectSingleNode('./CitadelHudEscapeMenu')
if ($null -eq $nativeRoot) {
    throw 'Current stock Escape layout does not have a CitadelHudEscapeMenu root panel.'
}

$menuCandidates = @($nativeRoot.SelectNodes('.//*[@id="Menu"]'))
$subOptionsCandidates = @()
foreach ($menu in $menuCandidates) {
    foreach ($candidate in $menu.SelectNodes('./*[@id="SubOptions"]')) {
        $quitCandidate = $candidate.SelectSingleNode('./*[@id="quit"]')
        $settingsCandidate = $candidate.SelectSingleNode('.//*[@id="settings"]')
        $feedbackCandidate = $candidate.SelectSingleNode('.//*[@id="PlayerFeedback"]')
        if ($null -ne $quitCandidate -and $null -ne $settingsCandidate -and $null -ne $feedbackCandidate) {
            $subOptionsCandidates += $candidate
        }
    }
}
if ($subOptionsCandidates.Count -ne 1) {
    throw "Expected exactly one native #Menu/#SubOptions with settings, PlayerFeedback, and direct #quit; found $($subOptionsCandidates.Count)."
}
$subOptions = $subOptionsCandidates[0]
$quit = $subOptions.SelectSingleNode('./*[@id="quit"]')
if ($null -eq $nativeRoot.SelectSingleNode('.//*[@id="DLTKEscapeLauncher"]')) {
    $launcher = $stockEscape.CreateElement('Button')
    $launcher.SetAttribute('id', 'DLTKEscapeLauncher')
    $launcher.SetAttribute('class', 'nav_menu_item minor')
    $launcher.SetAttribute('onactivate', '$.DLTK.UI.open();')
    $launcherLabel = $stockEscape.CreateElement('Label')
    $launcherLabel.SetAttribute('class', 'menuButtonLabel')
    $launcherLabel.SetAttribute('text', 'DLTK')
    [void]$launcher.AppendChild($launcherLabel)
    [void]$subOptions.InsertBefore($launcher, $quit)
} else {
    throw 'Current stock Escape layout unexpectedly already contains DLTKEscapeLauncher; refusing to create a duplicate.'
}

Add-IncludeNodes -TargetDocument $stockEscape -TemplateDocument $template -SectionName 'styles'
Add-IncludeNodes -TargetDocument $stockEscape -TemplateDocument $template -SectionName 'scripts'
$nativeRoot.AppendChild($stockEscape.ImportNode($templatePanel, $true)) | Out-Null

$patchedIntegrity = Get-IntegritySignatureCounts -Document $stockEscape
# Capture the stock counts independently by decompiling once before applying DLTK additions.
$stockEscapeForCompare = Get-StockAstDocument -ResourcePath 'panorama/layout/hud_escape_menu.vxml_c'
$stockCounts = Get-IntegritySignatureCounts -Document $stockEscapeForCompare
foreach ($signature in $stockCounts.Keys) {
    if (-not $patchedIntegrity.ContainsKey($signature) -or $patchedIntegrity[$signature] -lt $stockCounts[$signature]) {
        throw "Patched Escape layout did not retain original panel/handler signature: $signature"
    }
}
$launcherNodes = @($stockEscape.SelectNodes('//*[@id="DLTKEscapeLauncher"]'))
$finalQuit = $stockEscape.SelectSingleNode('/root/CitadelHudEscapeMenu//*[@id="SubOptions"]/*[@id="quit"]')
if ($launcherNodes.Count -ne 1 -or $null -eq $finalQuit -or $launcherNodes[0].ParentNode -ne $finalQuit.ParentNode -or
    $launcherNodes[0].NextSibling -ne $finalQuit) {
    throw 'DLTK launcher is not unique or is not immediately before native #quit.'
}

New-Item -ItemType Directory -Force -Path $GeneratedLayoutRoot | Out-Null
$baseOutputPath = Join-Path $GeneratedLayoutRoot 'base_hud.xml'
$escapeOutputPath = Join-Path $GeneratedLayoutRoot 'hud_escape_menu.xml'
Save-XmlDocument -Document $generatedBaseHud -Path $baseOutputPath
Save-XmlDocument -Document $stockEscape -Path $escapeOutputPath

$reloadedBase = [xml]::new()
$reloadedBase.Load($baseOutputPath)
$reloadedEscape = [xml]::new()
$reloadedEscape.Load($escapeOutputPath)
if ($null -eq $reloadedBase.SelectSingleNode('/root/scripts/include[@src="s2r://panorama/scripts/dltoolkit_bootstrap.vjs_c"]') -or
    $null -eq $reloadedEscape.SelectSingleNode('/root/CitadelHudEscapeMenu//*[@id="DLTKEscapeLauncher"]')) {
    throw 'Generated Panorama XML did not survive a parse/serialization round trip.'
}

$nativeControlCount = @($stockEscapeForCompare.SelectNodes('//*[self::Button or self::CitadelBindingButton or self::DropDown or self::ToggleButton or self::RadioButton]')).Count
Write-Output "Stock resource extraction: PASS (base_hud.vxml_c, hud_escape_menu.vxml_c from current pak01_dir.vpk)"
Write-Output "Stock controls/handlers retained: PASS ($nativeControlCount native controls; all ID/handler signatures retained)"
Write-Output 'Escape launcher placement: PASS (#SubOptions direct child, immediately before #quit; class nav_menu_item minor)'
Write-Output "Generated current-stock sources: $baseOutputPath ; $escapeOutputPath"
