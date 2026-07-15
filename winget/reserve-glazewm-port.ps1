# Reserve TCP port 6123 (GlazeWM's IPC port) as a persistent excluded port so
# the Hyper-V Host Network Service's dynamic exclusion range (which WSL2
# depends on) won't randomly claim it at boot. Must run elevated.
#
# Symptom when unreserved: on some boots GlazeWM fails to bind its IPC
# socket with "access denied (os error 10013)" because Hyper-V's per-boot
# dynamic port range happened to cover 6123. zebar / shell-exec / tacky
# reload all go dead as a result. Fix persists across reboots — winnat
# reads the persistent exclusion list during range allocation.
#
# Invoke this ONE time (manually with UAC, or via install.linux.sh's
# -Verb RunAs call). Idempotent — safe to re-run.

$ErrorActionPreference = 'Continue'
$port = 6123

Write-Host "[1/4] try a plain persistent reservation first..."
# Succeeds whenever $port isn't currently inside an active dynamic range —
# no service cycling needed, and the persistent store is respected on every
# subsequent boot regardless.
netsh int ipv4 add excludedportrange protocol=tcp startport=$port numberofports=1 store=persistent 2>&1 | Out-Host

$reserved = (netsh int ipv4 show excludedportrange tcp store=persistent | Out-String) -match "\b$port\b"

if (-not $reserved) {
  Write-Host "[2/4] port currently claimed — cycling winnat to release dynamic ranges..."
  # winnat only. Do NOT stop hns: it wedges in StopPending on some machines
  # (observed 2026-07-15) and `net stop` additionally blocks on an
  # interactive dependent-services Y/N prompt. winnat alone owns the dynamic
  # TCP allocations; restarting it re-reads the persistent exclusion list.
  # Run with WSL shut down (`wsl --shutdown`) so winnat releases cleanly.
  Stop-Service winnat -Force -ErrorAction SilentlyContinue
  netsh int ipv4 add excludedportrange protocol=tcp startport=$port numberofports=1 store=persistent 2>&1 | Out-Host
  Write-Host "[3/4] start winnat back (re-allocates ranges respecting the new exclusion)..."
  Start-Service winnat -ErrorAction SilentlyContinue
}

Write-Host "[4/4] verify..."
$lines = netsh int ipv4 show excludedportrange tcp store=persistent | Out-String
if ($lines -match "\b$port\b") {
  Write-Host "  OK: $port is now in the excluded list"
} else {
  Write-Host "  WARN: could not confirm $port reservation — check manually"
}
