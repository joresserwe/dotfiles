# Generates live config.yaml from WSL-side template based on current monitor
# count. Writes monitor_count × 3 workspaces (capped at 9 / 3 monitors) into
# the BEGIN/END generated blocks, leaves the rest of the template untouched.
# Called from the Hyper+C reload chain; triggers wm-reload-config itself so
# reload sees the fresh file (glazewm's shell-exec is fire-and-forget, so
# chaining reload in config.yaml would race the file write).

$ErrorActionPreference = 'Stop'

$glazewm    = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'
# Process env first, then User-registry env (bash -> powershell.exe doesn't
# inherit Windows User env; cmd.exe /c does. Fall back so both work.)
$template   = $env:GLAZEWM_TEMPLATE_PATH
if (-not $template) {
    $template = [Environment]::GetEnvironmentVariable('GLAZEWM_TEMPLATE_PATH', 'User')
}
$output     = Join-Path $env:USERPROFILE '.glzr\glazewm\config.yaml'
$maxMons    = 3
$wsPerMon   = 3

if (-not $template) {
    Write-Error "GLAZEWM_TEMPLATE_PATH env var not set — run install.linux.sh"
    exit 1
}
if (-not (Test-Path -LiteralPath $template)) {
    Write-Error "Template not readable: $template"
    exit 1
}

# Detect monitor count. Prefer glazewm IPC (same source-of-truth as bind
# indexes), but fall back to .NET Screen API when glazewm isn't up yet
# (first boot, post-crash) — otherwise the generator writes a 1-monitor
# config and glazewm fails with "No workspace config available to activate
# workspace." on the unbound monitor.
$n = 0
try {
    $res = & $glazewm query monitors 2>$null | ConvertFrom-Json
    if ($res.success) { $n = $res.data.monitors.Count }
} catch { }
if ($n -lt 1) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $n = [System.Windows.Forms.Screen]::AllScreens.Count
    } catch { $n = 1 }
}
$n = [Math]::Min([Math]::Max($n, 1), $maxMons)
$totalWs = $n * $wsPerMon

# Build the three generated blocks
$wsBlock    = for ($w = 1; $w -le $totalWs; $w++) {
    $mon = [Math]::Floor(($w - 1) / $wsPerMon)
    "  - { name: '$w', bind_to_monitor: $mon, keep_alive: true }"
}
$focusBlock = for ($w = 1; $w -le $totalWs; $w++) {
    "  - commands: ['focus --workspace $w']"
    "    bindings: ['lwin+$w']"
}
$moveBlock  = for ($w = 1; $w -le $totalWs; $w++) {
    "  - commands: ['move --workspace $w', 'focus --workspace $w', *delayed_redraw]"
    "    bindings: ['lwin+shift+$w']"
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
