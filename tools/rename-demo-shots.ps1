<#
.SYNOPSIS
    Copies the screenshots of a demo run (/br demo shot) under descriptive names.

.DESCRIPTION
    The hidden demo mode of Pardona's Buff Reminder takes a series of screenshots and records
    their order and names in the SavedVariables (BuffReminderDB.demoShots). This script reads
    that list, takes the screenshot files (WoWScrnShot_*.png) written since the run started,
    in chronological order, and COPIES them as "01-pardona-list.png", "02-pardona-food-menu.png"
    and so on into the output folder. The original screenshots are not changed.

    If the number of screenshots does not match the number of recorded shots, the script warns
    and stops without copying anything.

    Important: WoW writes the SavedVariables only on /reload, logout or exit. After the run,
    type /reload (or log out) before running this script.

    Format read from PardonasBuffReminder.lua (SavedVariables, written by the game):

        BuffReminderDB = {
            ["demoShots"] = {
                ["started"] = 1763650000,        -- Unix time (seconds) when the run started
                ["shots"] = {
                    {
                        ["n"] = 1,
                        ["name"] = "pardona-list",
                        ["t"] = 1763650004,      -- Unix time of the screenshot
                    }, -- [1]
                    ...
                },
            },
            ...
        }

    The block is located with a regular expression and brace matching; key order inside the
    tables does not matter.

.PARAMETER WowPath
    Game folder of the client (contains WTF and Screenshots).

.PARAMETER Account
    Account folder name under WTF\Account. Optional: without it, the only (or most recently
    written) PardonasBuffReminder.lua under WTF\Account\*\SavedVariables is used.

.PARAMETER OutDir
    Output folder for the renamed copies. Default: <WowPath>\Screenshots\PardonasDemo

.EXAMPLE
    .\tools\rename-demo-shots.ps1

    Uses the default WoW Forever folder and the most recent SavedVariables file.

.EXAMPLE
    .\tools\rename-demo-shots.ps1 -Account MYACCOUNT -OutDir D:\Images\BuffReminder
#>
[CmdletBinding()]
param(
    [string]$WowPath = 'C:\Program Files (x86)\World of Warcraft\_forever_',
    [string]$Account,
    [string]$OutDir
)

$ErrorActionPreference = 'Stop'

if (-not $OutDir) { $OutDir = Join-Path $WowPath 'Screenshots\PardonasDemo' }

# --- SavedVariables file -------------------------------------------------------------------
$accountRoot = Join-Path $WowPath 'WTF\Account'
if ($Account) {
    $svFile = Join-Path $accountRoot "$Account\SavedVariables\PardonasBuffReminder.lua"
    if (-not (Test-Path -LiteralPath $svFile)) { throw "SavedVariables file not found: $svFile" }
} else {
    $candidates = @(Get-ChildItem -Path (Join-Path $accountRoot '*\SavedVariables\PardonasBuffReminder.lua') -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending)
    if ($candidates.Count -eq 0) { throw "No PardonasBuffReminder.lua found under $accountRoot\*\SavedVariables" }
    if ($candidates.Count -gt 1) {
        Write-Warning ("Several accounts found, using the most recently written file: {0}" -f $candidates[0].FullName)
    }
    $svFile = $candidates[0].FullName
}
Write-Host "SavedVariables: $svFile"
$text = [IO.File]::ReadAllText($svFile)

# Returns the text of the table that starts at the first "{" at or after $start (brace matching,
# ignores braces inside double-quoted strings).
function Get-TableText([string]$s, [int]$start) {
    $open = $s.IndexOf('{', $start)
    if ($open -lt 0) { return $null }
    $depth = 0
    $inString = $false
    for ($i = $open; $i -lt $s.Length; $i++) {
        $c = $s[$i]
        if ($inString) {
            if ($c -eq '\') { $i++; continue }
            if ($c -eq '"') { $inString = $false }
            continue
        }
        if ($c -eq '"') { $inString = $true; continue }
        if ($c -eq '{') { $depth++ }
        elseif ($c -eq '}') {
            $depth--
            if ($depth -eq 0) { return $s.Substring($open, $i - $open + 1) }
        }
    }
    return $null
}

$m = [regex]::Match($text, '\["demoShots"\]\s*=\s*\{')
if (-not $m.Success) { throw 'No demoShots found. Run /br demo shot, then /reload, then this script.' }
$demo = Get-TableText $text $m.Index
$started = [regex]::Match($demo, '\["started"\]\s*=\s*(\d+)')
if (-not $started.Success) { throw 'demoShots has no "started" value.' }
$startedUnix = [long]$started.Groups[1].Value

$sm = [regex]::Match($demo, '\["shots"\]\s*=\s*\{')
$shots = @()
if ($sm.Success) {
    $shotsText = Get-TableText $demo $sm.Index
    # inner tables of the shots list (no nested tables inside an entry)
    foreach ($entry in [regex]::Matches($shotsText.Substring(1), '\{([^{}]*)\}')) {
        $body = $entry.Groups[1].Value
        $n = [regex]::Match($body, '\["n"\]\s*=\s*(\d+)')
        $name = [regex]::Match($body, '\["name"\]\s*=\s*"([^"]*)"')
        if ($n.Success -and $name.Success) {
            $shots += [pscustomobject]@{ N = [int]$n.Groups[1].Value; Name = $name.Groups[1].Value }
        }
    }
}
$shots = @($shots | Sort-Object N)
if ($shots.Count -eq 0) { throw 'demoShots contains no shots.' }

$startedLocal = [DateTimeOffset]::FromUnixTimeSeconds($startedUnix).LocalDateTime
Write-Host ("Run started {0}, {1} shots recorded" -f $startedLocal, $shots.Count)

# --- Screenshot files ----------------------------------------------------------------------
$shotDir = Join-Path $WowPath 'Screenshots'
# 2 s tolerance: "started" has whole seconds
$files = @(Get-ChildItem -Path (Join-Path $shotDir 'WoWScrnShot_*.png') -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $startedLocal.AddSeconds(-2) } |
    Sort-Object LastWriteTime, Name)

if ($files.Count -ne $shots.Count) {
    Write-Warning ("Found {0} screenshot(s) since the run started, but {1} shot(s) are recorded. Nothing copied." -f $files.Count, $shots.Count)
    foreach ($f in $files) { Write-Host ("  {0}  {1}" -f $f.LastWriteTime, $f.Name) }
    exit 1
}

if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

for ($i = 0; $i -lt $shots.Count; $i++) {
    $target = Join-Path $OutDir ('{0:D2}-{1}.png' -f $shots[$i].N, $shots[$i].Name)
    Copy-Item -LiteralPath $files[$i].FullName -Destination $target -Force
    Write-Host ("{0} -> {1}" -f $files[$i].Name, (Split-Path -Leaf $target))
}
Write-Host ("{0} file(s) copied to {1}" -f $shots.Count, $OutDir)
