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

Write-Host "[1/4] stop Hyper-V NAT service (releases dynamic port ranges)..."
# Also hns (Host Network Service) which seeds winnat's allocations.
net stop winnat 2>&1 | Out-Host
net stop hns 2>&1 | Out-Host

Write-Host "[2/4] persistently reserve TCP $port for GlazeWM IPC..."
# store=persistent survives reboot. Re-adding an already-reserved port is
# idempotent (no error).
netsh int ipv4 add excludedportrange protocol=tcp startport=$port numberofports=1 store=persistent 2>&1 | Out-Host

Write-Host "[3/4] start services back (re-allocates ranges respecting the new exclusion)..."
net start hns 2>&1 | Out-Host
net start winnat 2>&1 | Out-Host

Write-Host "[4/4] verify..."
$lines = netsh int ipv4 show excludedportrange tcp | Out-String
if ($lines -match "\b$port\b") {
  Write-Host "  OK: $port is now in the excluded list"
} else {
  Write-Host "  WARN: could not confirm $port reservation — check manually"
}
