# Called from the Hyper+C reload chain; triggers wm-reload-config itself so
# reload sees the fresh file (glazewm's shell-exec is fire-and-forget, so
# chaining reload in config.yaml would race the file write).

$ErrorActionPreference = 'Stop'

# PS 5.1 decodes native stdout via the console codepage while glazewm emits
# UTF-8 — without this, a Korean window title mis-decodes into invalid JSON
# and every query below parses to $null.
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$glazewm    = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'
# Process env first, then User-registry env (bash -> powershell.exe doesn't
# inherit Windows User env; cmd.exe /c does. Fall back so both work.)
$template   = $env:GLAZEWM_TEMPLATE_PATH
if (-not $template) {
    $template = [Environment]::GetEnvironmentVariable('GLAZEWM_TEMPLATE_PATH', 'User')
}
$output     = Join-Path $env:USERPROFILE '.glzr\glazewm\config.yaml'
$maxMons    = 3
$wsPerMon   = 5
$maxBound   = 10

if (-not $template) {
    Write-Error "GLAZEWM_TEMPLATE_PATH env var not set — run install.linux.sh"
    exit 1
}
if (-not (Test-Path -LiteralPath $template)) {
    Write-Error "Template not readable: $template"
    exit 1
}

# Spare inactive workspace configs are load-bearing: a monitor that appears
# while every config is already active stays workspace-less (observed
# 2026-07-22: RDP reconnect against a live config sized to 1 monitor left
# the second monitor empty; reload alone never repaired it).
$totalWs = $maxMons * $wsPerMon

# Build the three generated blocks
$wsBlock    = for ($w = 1; $w -le $totalWs; $w++) {
    $mon = [Math]::Floor(($w - 1) / $wsPerMon)
    "  - { name: '$w', bind_to_monitor: $mon }"
}
$focusBlock = for ($w = 1; $w -le $totalWs; $w++) {
    "  - commands: ['focus --workspace $w']"
    if ($w -le $maxBound) {
        $key = if ($w -eq 10) { '0' } else { "$w" }
        "    bindings: ['f13+$key', 'lwin+$key']"
    } else {
        "    bindings: ['ctrl+alt+f13+$($w - $maxBound)']"
    }
}
$moveBlock  = for ($w = 1; $w -le $totalWs; $w++) {
    "  - commands: ['move --workspace $w', 'focus --workspace $w', *recenter]"
    if ($w -le $maxBound) {
        $key = if ($w -eq 10) { '0' } else { "$w" }
        "    bindings: ['f13+shift+$key', 'lwin+shift+$key']"
    } else {
        "    bindings: ['ctrl+alt+f13+shift+$($w - $maxBound)']"
    }
}

function Replace-Between($lines, $beginPattern, $endPattern, $newBlock) {
    $out = New-Object System.Collections.Generic.List[string]
    $skipping = $false
    foreach ($line in $lines) {
        if ($line -match $beginPattern) {
            $out.Add($line)
            foreach ($nl in $newBlock) { $out.Add($nl) }
            $skipping = $true
            continue
        }
        if ($skipping -and $line -match $endPattern) {
            $out.Add($line)
            $skipping = $false
            continue
        }
        if (-not $skipping) { $out.Add($line) }
    }
    return $out
}

# Read as UTF-8 via .NET (Windows PowerShell 5's Get-Content doesn't always
# detect encoding correctly — mis-decoding Korean comments corrupts the file).
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$lines = [System.IO.File]::ReadAllLines($template, $utf8NoBom)
$lines = Replace-Between $lines 'BEGIN_GENERATED_WORKSPACES' 'END_GENERATED_WORKSPACES' $wsBlock
$lines = Replace-Between $lines 'BEGIN_GENERATED_WS_FOCUS'   'END_GENERATED_WS_FOCUS'   $focusBlock
$lines = Replace-Between $lines 'BEGIN_GENERATED_WS_MOVE'    'END_GENERATED_WS_MOVE'    $moveBlock

# Atomic write: stage to .tmp then replace (same volume, rename is atomic).
# Write UTF-8 *without* BOM — glazewm's YAML parser treats a leading BOM as
# a control char and refuses to load.
$tmp = "$output.tmp"
[System.IO.File]::WriteAllLines($tmp, $lines, $utf8NoBom)
Move-Item -LiteralPath $tmp -Destination $output -Force

# Trigger reload now that the file is in place.
& $glazewm command wm-reload-config | Out-Null
