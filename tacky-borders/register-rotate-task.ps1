# Registers the `tacky-rotate` Scheduled Task: runs rotate.ps1 at every logon
# and daily at 00:05. No elevation needed — rotate.ps1 only copies a yaml
# file; tacky-borders itself (which DOES need elevation) picks up the change
# via its watcher. Idempotent.
param(
  [Parameter(Mandatory = $true)] [string]$ScriptPath,
  [string]$TaskName = 'tacky-rotate'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ScriptPath)) {
  Write-Error "ScriptPath not found: $ScriptPath"
  exit 1
}

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

$action    = New-ScheduledTaskAction `
  -Execute 'powershell.exe' `
  -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $ScriptPath)

$t_logon   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$t_daily   = New-ScheduledTaskTrigger -Daily -At '00:05'
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -StartWhenAvailable `
  -MultipleInstances IgnoreNew `
  -ExecutionTimeLimit ([TimeSpan]::FromMinutes(1))

Register-ScheduledTask -TaskName $TaskName `
  -Action $action -Trigger @($t_logon, $t_daily) -Principal $principal -Settings $settings | Out-Null

# Apply today's pick right away so the new registration takes effect without
# waiting for the next logon.
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath
