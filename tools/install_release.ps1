[CmdletBinding()]
param(
    [string]$GameRoot
)

$ErrorActionPreference = 'Stop'

$Version = 'v1.0.0'
$ReleaseUrl = 'https://github.com/psiu7217/deadlock-MOD/releases/download/v1.0.0/DLTK_Runes_v1.0.0.vpk'
$ExpectedHash = '9990F935E835E5D72762C7E5D2168DABC720C0710FE0859E95F589393477825D'
$ExpectedSize = 157789
$TargetName = 'pak99_dir.vpk'

function Get-CanonicalLine {
    param([string]$Line)
    return (($Line.Trim()) -replace '[\t ]+', ' ')
}

function Find-DeadlockRoot {
    $steamRoots = @()

    foreach ($key in @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam'
    )) {
        try {
            $props = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
            foreach ($name in @('SteamPath', 'InstallPath')) {
                $value = $props.$name
                if ($value -and (Test-Path -LiteralPath $value -PathType Container)) {
                    $steamRoots += $value
                }
            }
        } catch {}
    }

    foreach ($path in @('C:\Program Files (x86)\Steam', 'C:\Program Files\Steam')) {
        if (Test-Path -LiteralPath $path -PathType Container) {
            $steamRoots += $path
        }
    }

    $steamRoots = @($steamRoots | Select-Object -Unique)
    $libraries = @($steamRoots)

    foreach ($steamRoot in $steamRoots) {
        $vdf = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path -LiteralPath $vdf -PathType Leaf)) {
            continue
        }

        try {
            $vdfText = [IO.File]::ReadAllText($vdf)
            foreach ($match in [regex]::Matches($vdfText, '"path"\s+"([^"]+)"')) {
                $library = $match.Groups[1].Value.Replace('\\', '\')
                if ($library -and (Test-Path -LiteralPath $library -PathType Container)) {
                    $libraries += $library
                }
            }
        } catch {}
    }

    foreach ($drive in Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue) {
        foreach ($suffix in @('SteamLibrary', 'Steam')) {
            $candidate = Join-Path $drive.Root $suffix
            if (Test-Path -LiteralPath $candidate -PathType Container) {
                $libraries += $candidate
            }
        }
    }

    $libraries = @($libraries | Select-Object -Unique)
    $found = @()

    foreach ($library in $libraries) {
        $candidate = Join-Path $library 'steamapps\common\Deadlock'
        $gameInfo = Join-Path $candidate 'game\citadel\gameinfo.gi'
        if (Test-Path -LiteralPath $gameInfo -PathType Leaf) {
            $found += $candidate
        }
    }

    $found = @($found | Select-Object -Unique)
    if ($found.Count -eq 1) {
        return $found[0]
    }
    if ($found.Count -gt 1) {
        throw "Multiple Deadlock installs found: $($found -join '; '). Re-run with -GameRoot <path>."
    }

    throw 'Deadlock installation was not found in Steam libraries. Re-run with -GameRoot <path-to-Deadlock>.'
}

function Read-TextPreserveEncoding {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [IO.File]::ReadAllBytes($Path)
    $offset = 0

    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $encoding = New-Object Text.UTF8Encoding($true)
        $offset = 3
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $encoding = New-Object Text.UnicodeEncoding($false, $true)
        $offset = 2
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $encoding = New-Object Text.UnicodeEncoding($true, $true)
        $offset = 2
    } else {
        $encoding = New-Object Text.UTF8Encoding($false)
    }

    $text = $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
    return [pscustomobject]@{
        Text = $text
        Encoding = $encoding
    }
}

function Get-SearchPathsRange {
    param([string[]]$Lines)

    $start = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*SearchPaths\b') {
            $start = $i
            break
        }
    }
    if ($start -lt 0) {
        throw 'SearchPaths section was not found in gameinfo.gi.'
    }

    $opened = $false
    $depth = 0
    $end = -1

    for ($i = $start; $i -lt $Lines.Count; $i++) {
        $opens = ([regex]::Matches($Lines[$i], '\{')).Count
        $closes = ([regex]::Matches($Lines[$i], '\}')).Count

        if ($opens -gt 0) {
            $opened = $true
        }
        if ($opened) {
            $depth += ($opens - $closes)
            if ($depth -eq 0 -and $i -gt $start) {
                $end = $i
                break
            }
        }
    }

    if (-not $opened -or $end -lt 0) {
        throw 'SearchPaths braces could not be parsed safely.'
    }

    return [pscustomobject]@{ Start = $start; End = $end }
}

function Test-DesiredMount {
    param([string[]]$Lines, [int]$Start, [int]$End)

    $desired = @(
        'Game citadel/addons',
        'Mod citadel',
        'Write citadel',
        'Game citadel',
        'Mod core',
        'Write core',
        'Game core'
    )

    for ($i = $Start; $i -le ($End - $desired.Count + 1); $i++) {
        $ok = $true
        for ($j = 0; $j -lt $desired.Count; $j++) {
            if ((Get-CanonicalLine $Lines[$i + $j]) -ne $desired[$j]) {
                $ok = $false
                break
            }
        }
        if ($ok) {
            return $true
        }
    }

    return $false
}

function Ensure-DltkMount {
    param([Parameter(Mandatory = $true)][string]$GameInfoPath)

    $file = Read-TextPreserveEncoding -Path $GameInfoPath
    $newline = if ($file.Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = [regex]::Split($file.Text, '\r?\n')
    $range = Get-SearchPathsRange -Lines $lines

    if (Test-DesiredMount -Lines $lines -Start $range.Start -End $range.End) {
        return $null
    }

    $allowed = @(
        'Game citadel/addons',
        'Mod citadel',
        'Write citadel',
        'Game citadel',
        'Mod core',
        'Write core',
        'Game core'
    )

    $rootIndexes = @()
    for ($i = $range.Start; $i -le $range.End; $i++) {
        $canonical = Get-CanonicalLine $lines[$i]
        if ($allowed -contains $canonical) {
            $rootIndexes += $i
        }
    }

    if ($rootIndexes.Count -lt 2) {
        throw 'Expected citadel/core SearchPaths anchors were not found. No config changes were made.'
    }

    $first = ($rootIndexes | Measure-Object -Minimum).Minimum
    $last = ($rootIndexes | Measure-Object -Maximum).Maximum

    $hasCitadel = $false
    $hasCore = $false
    for ($i = $first; $i -le $last; $i++) {
        $canonical = Get-CanonicalLine $lines[$i]
        if ($canonical -eq 'Game citadel') { $hasCitadel = $true }
        if ($canonical -eq 'Game core') { $hasCore = $true }
        if ($canonical -ne '' -and -not ($allowed -contains $canonical)) {
            throw "Unexpected SearchPaths content between citadel/core roots: '$($lines[$i])'. No config changes were made."
        }
    }

    if (-not $hasCitadel -or -not $hasCore) {
        throw 'Compatible Game citadel / Game core anchors were not found. No config changes were made.'
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$GameInfoPath.codex-backup-$timestamp"
    Copy-Item -LiteralPath $GameInfoPath -Destination $backup -ErrorAction Stop

    $indent = ([regex]::Match($lines[$first], '^[\t ]*')).Value
    $mountLines = @(
        $indent + 'Game                  citadel/addons',
        $indent + 'Mod                   citadel',
        $indent + 'Write                 citadel',
        $indent + 'Game                  citadel',
        $indent + 'Mod                   core',
        $indent + 'Write                 core',
        $indent + 'Game                  core'
    )

    $newLines = @()
    if ($first -gt 0) {
        $newLines += $lines[0..($first - 1)]
    }
    $newLines += $mountLines
    if ($last -lt ($lines.Count - 1)) {
        $newLines += $lines[($last + 1)..($lines.Count - 1)]
    }

    $newText = [string]::Join($newline, $newLines)
    $temp = "$GameInfoPath.dltk.tmp"

    try {
        [IO.File]::WriteAllText($temp, $newText, $file.Encoding)
        $check = Read-TextPreserveEncoding -Path $temp
        $checkLines = [regex]::Split($check.Text, '\r?\n')
        $checkRange = Get-SearchPathsRange -Lines $checkLines
        if (-not (Test-DesiredMount -Lines $checkLines -Start $checkRange.Start -End $checkRange.End)) {
            throw 'Generated gameinfo.gi did not contain the expected DLTK mount block.'
        }

        Copy-Item -LiteralPath $temp -Destination $GameInfoPath -Force
    } catch {
        Copy-Item -LiteralPath $backup -Destination $GameInfoPath -Force -ErrorAction SilentlyContinue
        throw
    } finally {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }

    $finalFile = Read-TextPreserveEncoding -Path $GameInfoPath
    $finalLines = [regex]::Split($finalFile.Text, '\r?\n')
    $finalRange = Get-SearchPathsRange -Lines $finalLines
    if (-not (Test-DesiredMount -Lines $finalLines -Start $finalRange.Start -End $finalRange.End)) {
        Copy-Item -LiteralPath $backup -Destination $GameInfoPath -Force -ErrorAction SilentlyContinue
        throw 'Final gameinfo.gi mount verification failed; original was restored.'
    }

    return $backup
}

try {
    $running = @(Get-Process -Name @('deadlock', 'project8') -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        throw 'Deadlock is running. Close the game and run the installer again.'
    }

    if (-not $GameRoot) {
        $GameRoot = Find-DeadlockRoot
    }

    $GameRoot = (Resolve-Path -LiteralPath $GameRoot).Path
    $gameInfo = Join-Path $GameRoot 'game\citadel\gameinfo.gi'
    if (-not (Test-Path -LiteralPath $gameInfo -PathType Leaf)) {
        throw "Invalid Deadlock root; gameinfo.gi not found: $gameInfo"
    }

    Write-Output "Deadlock: $GameRoot"

    $tempDir = Join-Path $env:TEMP 'DLTK-v1.0.0'
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    $download = Join-Path $tempDir 'DLTK_Runes_v1.0.0.vpk'

    Write-Output 'Downloading DLTK v1.0.0...'
    Invoke-WebRequest -UseBasicParsing -Uri $ReleaseUrl -OutFile $download

    $item = Get-Item -LiteralPath $download
    if ($item.Length -ne $ExpectedSize) {
        throw "Downloaded VPK size mismatch: $($item.Length) bytes (expected $ExpectedSize)."
    }

    $downloadHash = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($downloadHash -ne $ExpectedHash) {
        throw "Downloaded VPK SHA-256 mismatch: $downloadHash"
    }

    $gameInfoBackup = Ensure-DltkMount -GameInfoPath $gameInfo

    $addonRoot = Join-Path $GameRoot 'game\citadel\addons'
    New-Item -ItemType Directory -Force -Path $addonRoot | Out-Null
    $target = Join-Path $addonRoot $TargetName
    $vpkBackup = $null

    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $existingHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($existingHash -ne $ExpectedHash) {
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $vpkBackup = "$target.backup-before-DLTK-$timestamp"
            Copy-Item -LiteralPath $target -Destination $vpkBackup
        }
    }

    Copy-Item -LiteralPath $download -Destination $target -Force

    $installedHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($installedHash -ne $ExpectedHash) {
        throw "Installed VPK SHA-256 mismatch: $installedHash"
    }

    Write-Output ''
    Write-Output "DLTK $Version installed successfully."
    Write-Output "VPK: $target"
    Write-Output "SHA256: $installedHash"
    if ($gameInfoBackup) { Write-Output "gameinfo.gi backup: $gameInfoBackup" }
    if ($vpkBackup) { Write-Output "Previous VPK backup: $vpkBackup" }
    Write-Output 'You can launch Deadlock now.'
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
