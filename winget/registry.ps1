# Windows registry tweaks applied from WSL via install.linux.sh.
# Idempotent — safe to re-run.

# Block Win+L. Handled by winlogon so AutoHotkey cannot intercept it.
# Side effect: removes "Lock" from Ctrl+Alt+Del and the Start menu user tile.
$policiesSystem = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
if (-not (Test-Path $policiesSystem)) {
  New-Item -Path $policiesSystem -Force | Out-Null
}
Set-ItemProperty -Path $policiesSystem `
  -Name 'DisableLockWorkstation' -Value 1 -Type DWord -Force

# Block Explorer-handled Win+<key> shortcuts. REG_EXPAND_SZ, one char per key.
# D = Show Desktop, U = Accessibility. Windows processes these before AHK's
# keyboard hook, so `#d::`/`#u::` alone don't block the native behavior.
# AHK hotkeys still fire on top (hook sees the event first), so CycleOnMonitor
# in winget/winkey.ahk keeps working.
Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
  -Name 'DisabledHotkeys' -Value 'DU' -Type ExpandString -Force

# Block Win+G (Xbox Game Bar). On Windows 11 24H2+ neither DisabledHotkeys
# nor AppCaptureEnabled/GameDVR_Enabled stops the hotkey — only removing the
# Xbox Gaming Overlay AppX package does. Registry values below still disable
# DVR/recording features as a secondary cleanup.
$gameDVR = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'
if (-not (Test-Path $gameDVR)) {
  New-Item -Path $gameDVR -Force | Out-Null
}
Set-ItemProperty -Path $gameDVR `
  -Name 'AppCaptureEnabled' -Value 0 -Type DWord -Force

$gameConfigStore = 'HKCU:\System\GameConfigStore'
if (-not (Test-Path $gameConfigStore)) {
  New-Item -Path $gameConfigStore -Force | Out-Null
}
Set-ItemProperty -Path $gameConfigStore `
  -Name 'GameDVR_Enabled' -Value 0 -Type DWord -Force

Get-AppxPackage Microsoft.XboxGamingOverlay -ErrorAction SilentlyContinue |
  Remove-AppxPackage -ErrorAction SilentlyContinue

# Disable the Windows 11 system tray chevron/overflow so every tray icon is
# permanently flagged visible (TBSTATE_HIDDEN=0). Zebar's systray provider
# filters icons on is_visible and its initial-enumeration fallback is racy,
# so without this, icons like winkey.ahk flicker in/out of the bar. Blocklist
# in zebar/bar.html then controls what actually shows.
$trayNotify = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify'
if (-not (Test-Path $trayNotify)) {
  New-Item -Path $trayNotify -Force | Out-Null
}
Set-ItemProperty -Path $trayNotify `
  -Name 'SystemTrayChevronVisibility' -Value 0 -Type DWord -Force

# Taskbar auto-hide. StuckRects3.Settings is a binary blob; byte[8] controls
# visibility (0x03 = auto-hide, 0x02 = always show). Read-modify-write so the
# rest of the blob (position, alignment, etc.) is preserved across versions.
$stuckRects = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
$settings = (Get-ItemProperty -Path $stuckRects).Settings
if ($settings[8] -ne 3) {
  $settings[8] = 3
  Set-ItemProperty -Path $stuckRects -Name Settings -Value $settings
  Stop-Process -Name explorer -Force  # respawns with new setting
}

# CapsLock → Left Ctrl (mirrors Karabiner on macOS).
# Scancode Map: header(8) + count(4) + mapping(4) + null(4) = 20 bytes.
# Mapping entry is target-then-source: LCtrl (0x001D) ← CapsLock (0x003A).
$bytes = [byte[]](
  0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,
  0x02,0x00,0x00,0x00,
  0x1D,0x00,0x3A,0x00,
  0x00,0x00,0x00,0x00
)
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout' `
  -Name 'Scancode Map' -Value $bytes -Type Binary -Force
