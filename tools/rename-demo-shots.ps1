<#
.SYNOPSIS
    Copies the screenshots of a demo run (/br demo shot) under descriptive names, cropped to
    the shown reminders, menus or settings window, and writes crops.txt.

.DESCRIPTION
    The hidden demo mode of Pardona's Buff Reminder takes a series of screenshots from a scene
    list with fixed IDs (S02, C04, E09 ...) and records their order, IDs, names and crop
    rectangles in the SavedVariables (BuffReminderDB.demoShots). This script reads that list,
    takes the screenshot files (WoWScrnShot_*.png) written since the run started, in
    chronological order, and writes copies into the output folder:

      "<ID>-<name>.png"   for shots with an ID, e.g. "S08-restock-trade.png"
      "NN-<name>.png"     for shots of older runs without an ID, e.g. "01-pardona-list.png"

      default   cropped copy: crop rectangle plus a margin (-Margin, default 12 px) on each side
                (limited to the image); shots without a crop rectangle are copied uncropped
      -Full     additionally the uncropped image as "<base>-full.png"
      -NoCrop   only uncropped copies (no cropping at all)

    In addition the script writes crops.txt into the output folder, one line per image:

        id;file;x;y;w;h;imagewidth;imageheight

    id is empty for shots without an ID. x, y, w, h is the rectangle cut out of the screenshot
    (pixels, origin top left, margin included); for uncropped copies these four fields are empty.
    imagewidth and imageheight are the size of the original screenshot.

    If the number of screenshots does not match the number of recorded shots, the script warns
    and stops without writing anything. If an image size differs from the recorded screen size,
    the crop rectangle is scaled proportionally and a warning is shown.
    The original screenshots are never changed.

    Important: WoW writes the SavedVariables only on /reload, logout or exit. After the run,
    type /reload (or log out) before running this script.

    Format read from PardonasBuffReminder.lua (SavedVariables, written by the game):

        BuffReminderDB = {
            ["demoShots"] = {
                ["started"] = 1763650000,        -- Unix time (seconds) when the run started
                ["screen"] = {                   -- physical screen size in pixels (optional)
                    ["w"] = 3440,
                    ["h"] = 1440,
                },
                ["shots"] = {
                    {
                        ["n"] = 1,
                        ["id"] = "S02",          -- scene ID (missing in older runs)
                        ["name"] = "mixed-list",
                        ["t"] = 1763650004,      -- Unix time of the screenshot
                        ["crop"] = {             -- optional; screen pixels, origin top left
                            ["x"] = 1210,
                            ["y"] = 402,
                            ["w"] = 564,
                            ["h"] = 498,
                        },
                    }, -- [1]
                    ...
                },
            },
            ...
        }

    The blocks are located with regular expressions and brace matching; key order inside the
    tables does not matter.

    Cropping and reading the image size use System.Drawing (Windows PowerShell 5.1 and
    PowerShell 7 on Windows); the output is PNG (lossless).

.PARAMETER WowPath
    Game folder of the client (contains WTF and Screenshots).

.PARAMETER Account
    Account folder name under WTF\Account. Optional: without it, the only (or most recently
    written) PardonasBuffReminder.lua under WTF\Account\*\SavedVariables is used.

.PARAMETER OutDir
    Output folder for the copies and crops.txt. Default: <WowPath>\Screenshots\PardonasDemo

.PARAMETER Margin
    Margin in pixels added on each side of the crop rectangle. Default: 12

.PARAMETER Full
    Also write the uncropped images as "<base>-full.png".

.PARAMETER NoCrop
    Write only uncropped copies (no cropping at all).

.EXAMPLE
    .\tools\rename-demo-shots.ps1

    Uses the default WoW Forever folder and the most recent SavedVariables file; writes
    cropped copies ("S02-mixed-list.png" ...) and crops.txt.

.EXAMPLE
    .\tools\rename-demo-shots.ps1 -Full -Margin 32

    Cropped copies with a 32 px margin plus the uncropped images ("S02-mixed-list-full.png" ...).

.EXAMPLE
    .\tools\rename-demo-shots.ps1 -Account MYACCOUNT -OutDir D:\Images\BuffReminder -NoCrop
#>
[CmdletBinding()]
param(
    [string]$WowPath = 'C:\Program Files (x86)\World of Warcraft\_forever_',
    [string]$Account,
    [string]$OutDir,
    [ValidateRange(0, 1000)]
    [int]$Margin = 12,
    [switch]$Full,
    [switch]$NoCrop
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

# Texts of the direct child tables of a table text (e.g. the entries of the shots list).
function Get-ChildTables([string]$s) {
    $result = @()
    $depth = 0
    $inString = $false
    $begin = -1
    for ($i = 0; $i -lt $s.Length; $i++) {
        $c = $s[$i]
        if ($inString) {
            if ($c -eq '\') { $i++; continue }
            if ($c -eq '"') { $inString = $false }
            continue
        }
        if ($c -eq '"') { $inString = $true; continue }
        if ($c -eq '{') {
            $depth++
            if ($depth -eq 2) { $begin = $i }
        } elseif ($c -eq '}') {
            if ($depth -eq 2) { $result += $s.Substring($begin, $i - $begin + 1) }
            $depth--
        }
    }
    return ,$result
}

# Value of ["key"] = <number> in a table text; $null if missing.
function Get-Number([string]$s, [string]$key) {
    $m = [regex]::Match($s, '\["' + $key + '"\]\s*=\s*(-?\d+(?:\.\d+)?)')
    if ($m.Success) { return [double]$m.Groups[1].Value }
    return $null
}

# Value of ["key"] = "<text>" in a table text; $null if missing.
function Get-String([string]$s, [string]$key) {
    $m = [regex]::Match($s, '\["' + $key + '"\]\s*=\s*"([^"]*)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

# Sub-table ["key"] = { ... } of a table text; $null if missing.
function Get-SubTable([string]$s, [string]$key) {
    $m = [regex]::Match($s, '\["' + $key + '"\]\s*=\s*\{')
    if ($m.Success) { return Get-TableText $s $m.Index }
    return $null
}

$m = [regex]::Match($text, '\["demoShots"\]\s*=\s*\{')
if (-not $m.Success) { throw 'No demoShots found. Run /br demo shot, then /reload, then this script.' }
$demo = Get-TableText $text $m.Index
$startedUnix = Get-Number $demo 'started'
if ($null -eq $startedUnix) { throw 'demoShots has no "started" value.' }

$screen = $null
$screenText = Get-SubTable $demo 'screen'
if ($screenText) {
    $sw = Get-Number $screenText 'w'
    $sh = Get-Number $screenText 'h'
    if ($sw -gt 0 -and $sh -gt 0) { $screen = [pscustomobject]@{ W = $sw; H = $sh } }
}

$shots = @()
$shotsText = Get-SubTable $demo 'shots'
if ($shotsText) {
    foreach ($entry in (Get-ChildTables $shotsText)) {
        $n = Get-Number $entry 'n'
        $name = Get-String $entry 'name'
        if ($null -eq $n -or $null -eq $name) { continue }
        $id = Get-String $entry 'id'
        $crop = $null
        $cropText = Get-SubTable $entry 'crop'
        if ($cropText) {
            $cx = Get-Number $cropText 'x'; $cy = Get-Number $cropText 'y'
            $cw = Get-Number $cropText 'w'; $ch = Get-Number $cropText 'h'
            if ($null -ne $cx -and $null -ne $cy -and $cw -gt 0 -and $ch -gt 0) {
                $crop = [pscustomobject]@{ X = $cx; Y = $cy; W = $cw; H = $ch }
            }
        }
        $shots += [pscustomobject]@{ N = [int]$n; Id = $id; Name = $name; Crop = $crop }
    }
}
$shots = @($shots | Sort-Object N)
if ($shots.Count -eq 0) { throw 'demoShots contains no shots.' }

$startedLocal = [DateTimeOffset]::FromUnixTimeSeconds([long]$startedUnix).LocalDateTime
Write-Host ("Run started {0}, {1} shots recorded" -f $startedLocal, $shots.Count)
if ($screen) { Write-Host ("Recorded screen size: {0} x {1}" -f $screen.W, $screen.H) }

# --- Screenshot files ----------------------------------------------------------------------
$shotDir = Join-Path $WowPath 'Screenshots'
# 2 s tolerance: "started" has whole seconds
$files = @(Get-ChildItem -Path (Join-Path $shotDir 'WoWScrnShot_*.png') -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $startedLocal.AddSeconds(-2) } |
    Sort-Object LastWriteTime, Name)

if ($files.Count -ne $shots.Count) {
    Write-Warning ("Found {0} screenshot(s) since the run started, but {1} shot(s) are recorded. Nothing written." -f $files.Count, $shots.Count)
    foreach ($f in $files) { Write-Host ("  {0}  {1}" -f $f.LastWriteTime, $f.Name) }
    exit 1
}

if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
Add-Type -AssemblyName System.Drawing

# Opens $source (via stream, so the original file is not locked or changed), returns its size
# and - if $crop is given and $target set - writes the cropped copy to $target.
# Returns @{ W; H; Rect } (Rect = rectangle cut out, $null if not cropped).
function Invoke-Image([string]$source, [string]$target, $crop) {
    $stream = $null; $image = $null; $part = $null
    try {
        $stream = [IO.File]::OpenRead($source)
        $image = New-Object System.Drawing.Bitmap $stream
        $result = [pscustomobject]@{ W = $image.Width; H = $image.Height; Rect = $null }
        if (-not $crop -or -not $target) { return $result }
        $x = $crop.X; $y = $crop.Y; $w = $crop.W; $h = $crop.H
        if ($screen -and ($image.Width -ne $screen.W -or $image.Height -ne $screen.H)) {
            Write-Warning ("{0}: image is {1} x {2}, recorded screen {3} x {4}; scaling the crop rectangle" -f `
                (Split-Path -Leaf $source), $image.Width, $image.Height, $screen.W, $screen.H)
            $kx = $image.Width / $screen.W; $ky = $image.Height / $screen.H
            $x = $x * $kx; $w = $w * $kx; $y = $y * $ky; $h = $h * $ky
        }
        $left   = [Math]::Max(0, [int][Math]::Floor($x - $Margin))
        $top    = [Math]::Max(0, [int][Math]::Floor($y - $Margin))
        $right  = [Math]::Min($image.Width,  [int][Math]::Ceiling($x + $w + $Margin))
        $bottom = [Math]::Min($image.Height, [int][Math]::Ceiling($y + $h + $Margin))
        if ($right -le $left -or $bottom -le $top) { return $result }
        $rect = New-Object System.Drawing.Rectangle $left, $top, ($right - $left), ($bottom - $top)
        $part = $image.Clone($rect, $image.PixelFormat)
        $part.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
        $result.Rect = $rect
        return $result
    } finally {
        if ($part) { $part.Dispose() }
        if ($image) { $image.Dispose() }
        if ($stream) { $stream.Dispose() }
    }
}

$cropLines = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $shots.Count; $i++) {
    $shot = $shots[$i]
    $source = $files[$i].FullName
    if ($shot.Id) { $base = '{0}-{1}' -f $shot.Id, $shot.Name } else { $base = '{0:D2}-{1}' -f $shot.N, $shot.Name }
    $file = "$base.png"
    $target = Join-Path $OutDir $file
    $info = $null
    if ($NoCrop) {
        $info = Invoke-Image $source $null $null
        Copy-Item -LiteralPath $source -Destination $target -Force
        Write-Host ("{0} -> {1}" -f $files[$i].Name, $file)
    } else {
        $info = Invoke-Image $source $target $shot.Crop
        if ($info.Rect) {
            Write-Host ("{0} -> {1} (cropped)" -f $files[$i].Name, $file)
        } else {
            if ($shot.Crop) { Write-Warning ("{0}: crop rectangle outside the image, copied uncropped" -f $base) }
            Copy-Item -LiteralPath $source -Destination $target -Force
            Write-Host ("{0} -> {1} (uncropped, no crop rectangle)" -f $files[$i].Name, $file)
        }
        if ($Full) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $OutDir "$base-full.png") -Force
            Write-Host ("{0} -> {1}" -f $files[$i].Name, "$base-full.png")
        }
    }
    $r = $info.Rect
    if ($r) {
        $cropLines.Add(('{0};{1};{2};{3};{4};{5};{6};{7}' -f $shot.Id, $file, $r.X, $r.Y, $r.Width, $r.Height, $info.W, $info.H))
    } else {
        $cropLines.Add(('{0};{1};;;;;{2};{3}' -f $shot.Id, $file, $info.W, $info.H))
    }
}
$cropsFile = Join-Path $OutDir 'crops.txt'
[IO.File]::WriteAllText($cropsFile, (($cropLines -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("{0} shot(s) written to {1}, crop list: {2}" -f $shots.Count, $OutDir, $cropsFile)
