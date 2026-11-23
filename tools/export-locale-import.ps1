<#
.SYNOPSIS
    Regenerates tools/locale-import/enUS.txt from Locales/enUS.lua and checks the other import files.

.DESCRIPTION
    Locales/enUS.lua is the source of all phrase keys and English texts. This script writes every
    phrase line (L["KEY"] = "text") to tools/locale-import/enUS.txt, one per line and without the
    file header, ready for the CurseForge localization import (format: lua_additive_table).

    Every other *.txt file in tools/locale-import (e.g. deDE.txt) is then compared with enUS:
      - keys that do not exist in enUS are reported as warnings
      - keys of enUS that are missing in the file are listed

    The script only reads Locales/enUS.lua and writes enUS.txt; it never changes other files.
    Every phrase value must be one valid Lua string literal: a double quote inside a text must be
    escaped (\") - better use single ASCII quotes ('...'), since the CurseForge import also rejects
    typographic quotes there. A phrase line with an unescaped double quote stops the export
    (enUS.lua) or counts as an error (other files).
    Exit code 1 if a file contains unknown keys or invalid lines, otherwise 0 (missing keys are
    only listed).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\export-locale-import.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repo      = Split-Path -Parent $PSScriptRoot
$source    = Join-Path $repo 'Locales\enUS.lua'
$importDir = Join-Path $PSScriptRoot 'locale-import'
$utf8      = New-Object System.Text.UTF8Encoding($false)
# value: exactly one Lua string literal (inner double quotes only escaped)
$phrase    = '^L\["([A-Z][A-Z0-9_]*)"\]\s*=\s*"(?:[^"\\]|\\.)*"\s*$'
$script:invalidTotal = 0

function Get-PhraseKeys([string[]]$lines, [string]$name) {
    $keys = New-Object System.Collections.Generic.List[string]
    $n = 0
    foreach ($line in $lines) {
        $n++
        if ($line -match '^\s*$') { continue }
        if ($line -match $phrase) {
            $keys.Add($Matches[1])
        } else {
            Write-Warning ("{0}, line {1}: not a valid phrase line (unescaped quote?): {2}" -f $name, $n, $line)
            $script:invalidTotal++
        }
    }
    return ,$keys
}

if (-not (Test-Path $source)) { throw "Not found: $source" }
if (-not (Test-Path $importDir)) { New-Item -ItemType Directory -Path $importDir | Out-Null }

# 1. enUS.txt from Locales/enUS.lua (only the phrase lines, in file order)
$srcLines = [System.IO.File]::ReadAllLines($source, $utf8)
foreach ($line in $srcLines) {
    # looks like a phrase line, but its value is not one valid Lua string (e.g. unescaped quote)
    if ($line -match '^L\[' -and $line -notmatch $phrase) { throw "Invalid phrase line in enUS.lua: $line" }
}
$enLines = @($srcLines | Where-Object { $_ -match $phrase })
if ($enLines.Count -eq 0) { throw "No phrases found in $source" }
$enKeys = @{}
foreach ($line in $enLines) {
    [void]($line -match $phrase)
    if ($enKeys.ContainsKey($Matches[1])) { throw "Duplicate key in enUS.lua: $($Matches[1])" }
    $enKeys[$Matches[1]] = $true
}
$enTxt = Join-Path $importDir 'enUS.txt'
[System.IO.File]::WriteAllText($enTxt, (($enLines -join "`n") + "`n"), $utf8)
Write-Host ("enUS.txt: {0} phrases written" -f $enLines.Count)

# 2. other import files: unknown keys (warning) and missing keys (list)
$unknownTotal = 0
foreach ($file in Get-ChildItem -Path $importDir -Filter '*.txt' | Sort-Object Name) {
    if ($file.Name -eq 'enUS.txt') { continue }
    $keys = Get-PhraseKeys ([System.IO.File]::ReadAllLines($file.FullName, $utf8)) $file.Name
    $seen = @{}
    foreach ($k in $keys) {
        if ($seen.ContainsKey($k)) { Write-Warning ("{0}: duplicate key {1}" -f $file.Name, $k) }
        $seen[$k] = $true
    }
    $unknown = @($seen.Keys | Where-Object { -not $enKeys.ContainsKey($_) } | Sort-Object)
    $missing = @($enLines | ForEach-Object { [void]($_ -match $phrase); $Matches[1] } |
        Where-Object { -not $seen.ContainsKey($_) })
    Write-Host ("{0}: {1} phrases, {2} unknown, {3} missing" -f $file.Name, $seen.Count, $unknown.Count, $missing.Count)
    foreach ($k in $unknown) { Write-Warning ("{0}: key not in enUS: {1}" -f $file.Name, $k) }
    foreach ($k in $missing) { Write-Host ("  missing: {0}" -f $k) }
    $unknownTotal += $unknown.Count
}

if ($unknownTotal -gt 0 -or $script:invalidTotal -gt 0) { exit 1 }
exit 0
