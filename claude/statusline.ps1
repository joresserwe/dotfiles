# Claude Code statusline — compact 1-line style
# model + effort | folder | git branch/status | context bar (color-coded) | rate limits
$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$raw = [Console]::In.ReadToEnd()
$d = $raw | ConvertFrom-Json
if (-not $d) { exit 0 }

$E   = [char]27
$R   = "$E[0m"
$SEP = " $E[38;5;238m│$R "

# ── Line 1 ──────────────────────────────────────────────
$model = $d.model.display_name
$line1 = "$E[1;38;5;141m🤖 $model$R"
if ($d.effort.level) { $line1 += " $E[38;5;221m⚡$($d.effort.level)$R" }

$cwd = $d.workspace.current_dir
$dir = Split-Path -Leaf $cwd
$line1 += $SEP + "$E[38;5;75m📁 $dir$R"

$branch = git -C $cwd branch --show-current 2>$null
if ($branch) {
    $staged = 0; $modified = 0; $untracked = 0
    $status = git -C $cwd status --porcelain 2>$null
    foreach ($l in $status) {
        if ($l.Length -lt 2) { continue }
        if ($l[0] -eq '?') { $untracked++; continue }
        if ($l[0] -ne ' ') { $staged++ }
        if ($l[1] -ne ' ') { $modified++ }
    }
    $g = "$E[38;5;114m🌿 $branch$R"
    if ($staged)    { $g += " $E[38;5;114m●$staged$R" }
    if ($modified)  { $g += " $E[38;5;221m~$modified$R" }
    if ($untracked) { $g += " $E[38;5;245m?$untracked$R" }
    $line1 += $SEP + $g
}

$pct = 0
if ($null -ne $d.context_window.used_percentage) {
    $pct = [math]::Floor($d.context_window.used_percentage)
}
$barColor = if ($pct -ge 85) { '38;5;203' } elseif ($pct -ge 60) { '38;5;221' } else { '38;5;114' }
$width  = 10
$filled = [math]::Min([math]::Floor($pct * $width / 100), $width)
$bar    = ('█' * $filled) + ('░' * ($width - $filled))

$usedTok = [math]::Round(($d.context_window.total_input_tokens + 0) / 1000)
$sizeTok = [math]::Round(($d.context_window.context_window_size + 0) / 1000)
$line1 += $SEP + "🧠 $E[${barColor}m$bar$R $E[1m$pct%$R $E[38;5;245m(${usedTok}k/${sizeTok}k)$R"

$cost = $d.cost.total_cost_usd + 0
$line1 += $SEP + "💰 $E[38;5;221m`$$('{0:N2}' -f $cost)$R"

$ms = $d.cost.total_duration_ms + 0
$totalMin = [math]::Floor($ms / 60000)
$h = [math]::Floor($totalMin / 60); $m = $totalMin % 60
$dur = if ($h -gt 0) { "${h}h ${m}m" } else { "${m}m" }
$line1 += $SEP + "⏱️ $E[38;5;245m$dur$R"

function Get-RLColor($p) {
    if ($p -ge 80) { '38;5;203' } elseif ($p -ge 50) { '38;5;221' } else { '38;5;114' }
}
$rl = @()
if ($null -ne $d.rate_limits.five_hour.used_percentage) {
    $p = [math]::Round($d.rate_limits.five_hour.used_percentage)
    $rl += "$E[38;5;245m5h$R $E[$(Get-RLColor $p)m$p%$R"
}
if ($null -ne $d.rate_limits.seven_day.used_percentage) {
    $p = [math]::Round($d.rate_limits.seven_day.used_percentage)
    $rl += "$E[38;5;245m7d$R $E[$(Get-RLColor $p)m$p%$R"
}
if ($rl.Count) { $line1 += $SEP + ($rl -join " $E[38;5;238m·$R ") }

Write-Output $line1
