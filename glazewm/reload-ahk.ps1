# Minimal AHK recovery — hard kill + wait + fresh spawn. Nothing else.
#
# Why this is stripped down: when invoked from glazewm's Hyper+C chain, this
# runs in PARALLEL with generate-config.ps1 (which issues wm-reload-config and
# makes glazewm reinstall its own keyboard hook), reload-zebar.ps1 and
# tacky-borders/reload.ps1. Any extra work here (registry reapply, UNC copy,
# logging overhead) lengthens the window during which AHK's hook install
# overlaps with glazewm's hook reinstall — empirically that's when the new
# AHK lands in "process alive, hook deaf" state. WSL-side invocation of an
# equally small command recovers reliably precisely because it doesn't race
# the glazewm reload. So: match that minimal command here.
#
# The earlier fat version did: registry reapply, UNC->local sync, Stop-Process
# then taskkill, Add-Content logging, then Start-Process. All of that was
# measured to take ~500ms between kill and spawn. That window coincides with
# glazewm's own hook reinstall during Hyper+C, and the race resolution was
# unfavorable. This version sticks to taskkill + wait + Start-Process, plus a
# deliberate 300ms pause AFTER the old process is gone but BEFORE the new
# one spawns, to put AHK's hook install strictly after glazewm's reinstall.

$AhkExe      = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$LocalScript = Join-Path $env:USERPROFILE '.config\winkey\winkey.ahk'
$__log       = Join-Path $env:TEMP 'reload-ahk.log'

"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') ENTER pid=$PID" | Add-Content -Path $__log -EA SilentlyContinue

& taskkill.exe /F /IM AutoHotkey64.exe /T 2>&1 | Out-Null
$deadline = (Get-Date).AddSeconds(3)
while ((Get-Date) -lt $deadline -and (Get-Process AutoHotkey64 -EA SilentlyContinue)) {
  Start-Sleep -Milliseconds 100
}

# 300ms breather — lets glazewm finish its own hook reinstall (triggered by
# the sibling generate-config.ps1 → wm-reload-config) before AHK installs.
Start-Sleep -Milliseconds 300

Start-Process -WindowStyle Hidden -FilePath $AhkExe -ArgumentList "`"$LocalScript`""

"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') EXIT" | Add-Content -Path $__log -EA SilentlyContinue
