param([Parameter(Mandatory = $true)][ValidateSet('install', 'uninstall')][string]$Action)
$ErrorActionPreference = 'Stop'

try {
    $gameDir = Split-Path -Parent $PSScriptRoot
    $cfgPath = Join-Path $gameDir 'override.cfg'
    if (-not (Test-Path -LiteralPath (Join-Path $gameDir 'Buckshot Roulette.exe') -PathType Leaf)) {
        throw 'Place the ChallengePack folder next to Buckshot Roulette.exe first.'
    }
    if ($Action -eq 'install' -and -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'challengepack.gd'))) {
        throw 'challengepack.gd is missing. Extract the complete mod archive.'
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $text = ''
    if (Test-Path -LiteralPath $cfgPath) { $text = [IO.File]::ReadAllText($cfgPath, $utf8) }
    $newline = "`n"
    if ($text.Contains("`r`n")) { $newline = "`r`n" }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    if ($text.Length -gt 0) {
        foreach ($line in ($text -split '\r?\n')) { $lines.Add($line) }
    }
    $section = ''
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[([^\]]+)\]\s*(?:;.*)?$') { $section = $Matches[1] }
        if ($section -eq 'autoload' -and $lines[$i] -match '^\s*ChallengePack\s*=') {
            $lines.RemoveAt($i)
            $i--
        }
    }
    if ($Action -eq 'install') {
        $scriptPath = (Join-Path $PSScriptRoot 'challengepack.gd').Replace('\', '/')
        $entry = 'ChallengePack="*' + $scriptPath + '"'
        $header = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*\[autoload\]\s*(?:;.*)?$') { $header = $i; break }
        }
        if ($header -lt 0) {
            if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -ne '') { $lines.Add('') }
            $lines.Add('[autoload]')
            $header = $lines.Count - 1
        }
        $lines.Insert($header + 1, $entry)
    }
    else {
        # Remove a now-empty autoload section, keeping comments and all other sections.
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            if ($lines[$i] -notmatch '^\s*\[autoload\]\s*$') { continue }
            $end = $i + 1
            while ($end -lt $lines.Count -and $lines[$end] -notmatch '^\s*\[') { $end++ }
            $hasContent = $false
            for ($j = $i + 1; $j -lt $end; $j++) {
                if ($lines[$j].Trim().Length -gt 0) { $hasContent = $true }
            }
            if (-not $hasContent) { $lines.RemoveRange($i, $end - $i) }
        }
    }
    $result = [string]::Join($newline, $lines.ToArray())
    if ($result.Trim().Length -eq 0) {
        if (Test-Path -LiteralPath $cfgPath) { Remove-Item -LiteralPath $cfgPath }
    }
    else {
        if (-not $result.EndsWith($newline)) { $result += $newline }
        [IO.File]::WriteAllText($cfgPath, $result, $utf8)
    }
    Write-Host "ChallengePack: $Action completed."
    exit 0
}
catch {
    Write-Error $_
    exit 1
}
