# Registers a Scheduled Task that launches tacky-borders.exe at logon with
# Highest run level. Tacky-borders needs High integrity to call SetWindowPos
# on GlazeWM-managed windows (glazewm + most tiled app windows inherit High
# because glazewm itself runs elevated to manage elevated windows). UIPI
# blocks Medium -> High SetWindowPos, so a Startup-folder launch (Medium) can't
# draw borders on those windows — logged as 0x80070005 ACCESS_DENIED.
#
# Interactive logon type keeps the process in the user's session (required for
# drawing visible borders). 30s startup delay mirrors winkey.ahk and gives the
# shell/DWM time to settle. Invoked idempotently by install.linux.sh.
param(
  [Parameter(Mandatory = $true)] [string]$ExePath,
  [string]$TaskName = 'tacky-borders'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ExePath)) {
  Write-Error "ExePath not found: $ExePath"
  exit 1
}

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

$action    = New-ScheduledTaskAction -Execute $ExePath -WorkingDirectory (Split-Path -Parent $ExePath)
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger.Delay = 'PT30S'
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -StartWhenAvailable `
  -MultipleInstances IgnoreNew `
  -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask -TaskName $TaskName `
  -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null

# Apply immediately: kill any Medium-integrity instance spawned from the
# previous Startup-folder .lnk, then start the task so the freshly elevated
# process picks up the new integrity level without waiting for next logon.
Get-Process tacky-borders -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName $TaskName
