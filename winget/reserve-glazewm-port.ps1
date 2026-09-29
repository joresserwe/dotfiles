# Reserve TCP ports 6123 (GlazeWM IPC) and 6124 (Zebar's asset server) so
# the Hyper-V Host Network Service's dynamic exclusion range (which WSL2
# depends on) won't randomly claim it at boot. Must run elevated.
#
# Symptom when unreserved: on some boots GlazeWM fails to bind its IPC
# socket with "access denied (os error 10013)" because Hyper-V's per-boot
# dynamic port range happened to cover 6123. zebar / shell-exec / tacky
# reload all go dead as a result. Fix persists across reboots — winnat
# reads the persistent exclusion list during range allocation.
#
# Zebar 3.3.1 keeps its windows alive when port 6124 fails to bind, leaving
# a white network-error page even after Hyper+C (observed 2026-09-18).

param([switch]$RestartWinNat)

$ErrorActionPreference = 'Stop'
$ports = @(6123, 6124)

function Get-UnreservedPorts {
  # store=persistent returned no rows even with an administered 6123 range
  # on 2026-09-18; active ranges marked '*' distinguish it from Hyper-V's.
  $lines = netsh int ipv4 show excludedportrange protocol=tcp store=active
  if ($LASTEXITCODE -ne 0) { throw 'Could not read administered TCP reservations.' }
  $ranges = @($lines | ForEach-Object {
    if ($_ -match '^\s*(\d+)\s+(\d+)\s*\*\s*$') {
      [pscustomobject]@{ Start = [int]$Matches[1]; End = [int]$Matches[2] }
    }
  })
  $ports | Where-Object {
    $port = $_
    -not ($ranges | Where-Object { $_.Start -le $port -and $_.End -ge $port })
  }
}

Write-Host 'Checking GlazeWM and Zebar TCP reservations...'
# Succeeds whenever $port isn't currently inside an active dynamic range —
# no service cycling needed, and the persistent store is respected on every
# subsequent boot regardless.
foreach ($port in @(Get-UnreservedPorts)) {
  netsh int ipv4 add excludedportrange protocol=tcp startport=$port numberofports=1 store=persistent 2>&1 | Out-Host
}

$pending = @(Get-UnreservedPorts)
if ($pending.Count -gt 0) {
  if (-not $RestartWinNat) {
    throw "TCP $($pending -join ', ') could not be reserved. In an elevated Windows PowerShell, run wsl --shutdown, then rerun this script with -RestartWinNat."
  }
  Write-Host 'Cycling winnat to release dynamic ranges...'
  # winnat only. Do NOT stop hns: it wedges in StopPending on some machines
  # (observed 2026-07-15) and `net stop` additionally blocks on an
  # interactive dependent-services Y/N prompt. winnat alone owns the dynamic
  # TCP allocations; restarting it re-reads the persistent exclusion list.
  # Run with WSL shut down (`wsl --shutdown`) so winnat releases cleanly.
  try {
    Stop-Service winnat -Force
    foreach ($port in $pending) {
      netsh int ipv4 add excludedportrange protocol=tcp startport=$port numberofports=1 store=persistent 2>&1 | Out-Host
    }
  } finally {
    Start-Service winnat
  }
}

$pending = @(Get-UnreservedPorts)
if ($pending.Count -gt 0) {
  throw "Could not confirm administered TCP reservations for $($pending -join ', ')."
}
Write-Host 'OK: TCP 6123 (GlazeWM) and 6124 (Zebar) are protected from dynamic port exclusions.'
