# Must run from the %USERPROFILE%\.dotfiles mirror — \\wsl.localhost paths
# are unreachable exactly when this runs (WSL off).
param([string]$Distro = 'Ubuntu', [switch]$Register)

$ErrorActionPreference = 'Stop'

if ($Register) {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Register', '-Distro', $Distro)
    exit
  }
  $vbs = Join-Path $PSScriptRoot 'run-hidden.vbs'
  $act = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"{0}" "{1}"' -f $vbs, $PSCommandPath)
  # 04:30/06:30: after the WSL-side daily fstrim window (~00:00-01:40) —
  # compact only reclaims blocks fstrim has already released.
  $trg = @(
    (New-ScheduledTaskTrigger -Daily -At '04:30'),
    (New-ScheduledTaskTrigger -Daily -At '06:30')
  )
  $set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
  $prn = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
  Register-ScheduledTask -TaskName 'wsl-autocompact' -Action $act -Trigger $trg -Settings $set -Principal $prn -Force | Out-Null
  exit
}

$log = Join-Path $env:TEMP 'wsl-autocompact.log'
function Write-Log([string]$m) {
  "{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $m | Add-Content -Path $log
}

# interop output is UTF-16; embedded NULs survive the join
$running = ((wsl.exe --list --running --quiet) -join ' ') -replace "`0", ''
if ($running.Trim()) { Write-Log "skip: WSL running [$($running.Trim())]"; exit 0 }

$lxss = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
$guid = (Get-ChildItem $lxss | Where-Object { (Get-ItemProperty $_.PSPath).DistributionName -eq $Distro }).PSChildName
if (-not $guid) { Write-Log "abort: distro '$Distro' not in Lxss registry"; exit 1 }
$vhd = Join-Path (Get-ItemProperty "$lxss\$guid").BasePath 'ext4.vhdx'
if (-not (Test-Path $vhd)) { Write-Log "abort: vhdx not found: $vhd"; exit 1 }

$before = (Get-Item $vhd).Length
$statusPath = Join-Path $env:TEMP 'wsl-autocompact.status'
$floor = 0L
$stale = $true
if (Test-Path $statusPath) {
  $floor = [long](Get-Content $statusPath -First 1)
  $stale = (Get-Item $statusPath).LastWriteTime -lt (Get-Date).AddDays(-7)
}
if (-not $stale -and ($before - $floor) -lt 3GB) {
  Write-Log ("skip: {0:N1} GB, grown <3 GB since last compact (<7 days ago)" -f ($before / 1GB))
  exit 0
}

$after = $before
$sw = [Diagnostics.Stopwatch]::StartNew()
try {
  Add-Type -Path (Join-Path $PSScriptRoot 'wsl-vhd-compact.cs')
  [WslVhd]::Compact($vhd)
  $after = (Get-Item $vhd).Length
  Set-Content -Path $statusPath -Value $after
  Write-Log ("compacted {0:N1} -> {1:N1} GB in {2:N0}s" -f ($before / 1GB), ($after / 1GB), $sw.Elapsed.TotalSeconds)
} catch {
  Write-Log ("compact failed after {0:N0}s: {1}" -f $sw.Elapsed.TotalSeconds, $_.Exception.GetBaseException().Message)
}

$free = (Get-PSDrive C).Free
Write-Log ("C: free {0:N1} GB" -f ($free / 1GB))
if ($free -lt 10GB) {
  msg.exe * ("C: is low: {0:N1} GB free (WSL vhdx {1:N1} GB). Clean up or run wsl-compact.ps1." -f ($free / 1GB), ($after / 1GB))
}
