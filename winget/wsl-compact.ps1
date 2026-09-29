# Must run from the %USERPROFILE%\.dotfiles mirror, not the \\wsl.localhost
# UNC — the script's own source vanishes at `wsl --shutdown` mid-run.
param([string]$Distro = 'Ubuntu')

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Distro', $Distro)
  exit
}

$lxss = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
$guid = (Get-ChildItem $lxss | Where-Object { (Get-ItemProperty $_.PSPath).DistributionName -eq $Distro }).PSChildName
if (-not $guid) { Write-Error "distro '$Distro' not found in Lxss registry"; exit 1 }
$vhd = Join-Path (Get-ItemProperty "$lxss\$guid").BasePath 'ext4.vhdx'
if (-not (Test-Path $vhd)) { Write-Error "vhdx not found: $vhd"; exit 1 }

$before = (Get-Item $vhd).Length / 1GB
Write-Host ("{0}: {1:N1} GB before compact" -f $vhd, $before)

wsl.exe -d $Distro -u root fstrim /
wsl.exe --shutdown
# wslservice keeps the vhdx handle for a few seconds after shutdown
Start-Sleep -Seconds 8

$sw = [Diagnostics.Stopwatch]::StartNew()
try {
  Add-Type -Path (Join-Path $PSScriptRoot 'wsl-vhd-compact.cs')
  [WslVhd]::Compact($vhd)
  $after = (Get-Item $vhd).Length / 1GB
  Write-Host ("done: {0:N1} GB -> {1:N1} GB (freed {2:N1} GB) in {3:N0}s" -f $before, $after, ($before - $after), $sw.Elapsed.TotalSeconds)
} catch {
  Write-Host ("compact failed after {0:N0}s: {1}" -f $sw.Elapsed.TotalSeconds, $_.Exception.GetBaseException().Message)
}
Read-Host 'press Enter to close'
