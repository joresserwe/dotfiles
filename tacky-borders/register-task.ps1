# Registers the 'tacky-borders' Scheduled Task at RunLevel=Highest.
#
# Action = wscript.exe <UNC launch.vbs>. The VBS wrapper handles kill+launch
# under Highest integrity so it can reap a prior Highest tacky-borders (UIPI
# blocks Medium->High termination). wscript is GUI-subsystem, so no console
# flashes on reload — powershell.exe would flash even with -WindowStyle
# Hidden, and cmd.exe can't escape the flash either. Task Scheduler's native
# MultipleInstances=StopExisting is not enough here because tacky-borders'
# own single-instance mutex races the new process and pops "an instance is
# already running" on every reload; the VBS does taskkill /F + wait, which
# waits for the mutex to release before launching.
#
# Highest integrity is required for SetWindowPos on GlazeWM-managed windows:
# glazewm runs elevated, most tiled windows inherit High through the launch
# chain, and UIPI blocks Medium->High SetWindowPos (logged as 0x80070005).
#
# Interactive logon type keeps the process in the user's session (required
# for drawing visible borders). 30s startup delay mirrors winkey.ahk and
# gives the shell/DWM time to settle. Invoked idempotently by install.linux.sh.
param(
  [Parameter(Mandatory = $true)] [string]$ExePath,
  [Parameter(Mandatory = $true)] [string]$LaunchVbs,
  [string]$TaskName = 'tacky-borders'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ExePath)) {
  Write-Error "ExePath not found: $ExePath"
  exit 1
}
if (-not (Test-Path $LaunchVbs)) {
  Write-Error "LaunchVbs not found: $LaunchVbs"
  exit 1
}

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

# Purge every other known autostart path so logon produces exactly one instance
# (symptom when missed: tacky-borders' own "an instance is already running;
# continue anyways?" dialog pops on login). The Scheduled Task below is the
# single source of truth for launch; anything else racing it is stale.
$startupLnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\tacky-borders.lnk'
if (Test-Path $startupLnk) { Remove-Item -Force $startupLnk -ErrorAction SilentlyContinue }
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
  -Name 'tacky-borders' -ErrorAction SilentlyContinue

# Register via the Schedule.Service COM API rather than the PowerShell cmdlet
# wrappers: New-ScheduledTaskSettingsSet -MultipleInstances only exposes
# Parallel/Queue/IgnoreNew (enum gap in the CDXML-generated cmdlet), and the
# CIM-level Set-ScheduledTask flip also refuses "StopExisting". The COM API
# accepts integer MultipleInstances codes directly:
#   0 = Parallel, 1 = Queue, 2 = IgnoreNew, 3 = StopExisting
$svc = New-Object -ComObject Schedule.Service
$svc.Connect()
$def = $svc.NewTask(0)

$def.RegistrationInfo.Author      = 'dotfiles/tacky-borders/register-task.ps1'

$def.Principal.UserId    = "$env:USERDOMAIN\$env:USERNAME"
$def.Principal.LogonType = 3   # TASK_LOGON_INTERACTIVE_TOKEN
$def.Principal.RunLevel  = 1   # TASK_RUNLEVEL_HIGHEST

$def.Settings.AllowDemandStart       = $true
$def.Settings.DisallowStartIfOnBatteries = $false
$def.Settings.StopIfGoingOnBatteries = $false
$def.Settings.StartWhenAvailable     = $true
$def.Settings.ExecutionTimeLimit     = 'PT0S'
# MultipleInstances can stay Parallel (=0) because the VBS wrapper does its
# own kill-first-then-launch. StopExisting here would just add an extra
# no-op signal to the previous wscript.exe (which is already done by the
# time Start-ScheduledTask returns).
$def.Settings.MultipleInstances      = 0   # TASK_INSTANCES_PARALLEL

$trigger = $def.Triggers.Create(9)  # TASK_TRIGGER_LOGON
$trigger.UserId = "$env:USERDOMAIN\$env:USERNAME"
$trigger.Delay  = 'PT30S'
$trigger.Enabled = $true

$action = $def.Actions.Create(0)   # TASK_ACTION_EXEC
$action.Path             = 'wscript.exe'
$action.Arguments        = '"' + $LaunchVbs + '"'
$action.WorkingDirectory = Split-Path -Parent $ExePath

# Register as the current user at TASK_LOGON_INTERACTIVE_TOKEN (logonType=3).
# Password arg is ignored for interactive-token logon. CreateOrUpdate=6.
$svc.GetFolder('\').RegisterTaskDefinition(
  $TaskName, $def, 6, "$env:USERDOMAIN\$env:USERNAME", $null, 3, $null
) | Out-Null

# Apply immediately: StopExisting reaps any running instance (task's action
# is tacky-borders.exe directly; Task Scheduler service runs as LocalSystem
# and can kill the prior Highest-integrity instance regardless of UIPI).
Start-ScheduledTask -TaskName $TaskName
