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

# Block Explorer-handled Win+<key> shortcuts. REG_SZ, one char per key.
# D = Show Desktop, U = Accessibility, H = Voice typing. Windows processes these before AHK's
# keyboard hook, so `#d::`/`#u::` alone don't block the native behavior.
# AHK hotkeys still fire on top (hook sees the event first), so CycleOnMonitor
# in winget/winkey.ahk keeps working.
# Type MUST be REG_SZ (String): Explorer silently ignores REG_EXPAND_SZ here —
# symptom was Win+U still opening Accessibility even with the value set.
Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
  -Name 'DisabledHotkeys' -Value 'DUH' -Type String -Force

# LowLevelHooksTimeout — raise from the Windows default (300ms) to 10s so
# Windows doesn't silently remove AHK's WH_KEYBOARD_LL hook if the callback
# doesn't respond during a busy cold boot. Without this, hook-based hotkeys
# (Hyper via VK19, CycleOnMonitor) can be dead
# from first login with no visible error. winkey.ahk's InstallKeybdHook
# reinstall at 5s catches the acute race; this prevents future disables.
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' `
  -Name 'LowLevelHooksTimeout' -Value 10000 -Type DWord -Force

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

# CapsLock → Left Ctrl (mirrors Karabiner on macOS), and
# LWin/RWin → F13: Windows never sees a Win key at all, so every native
# Win+<x> (including winlogon's Win+L, which no policy or hook can intercept
# on a Citrix client) is dead at the kernel. glazewm binds f13+<key>
# DIRECTLY (config.yaml) — nothing re-materializes a Win key, so the
# policies above are only a safety net for pre-reboot / unmapped states.
# Scancode Map: header(8) + count(4) + mapping(4)*n + null(4).
# Mapping entry is target-then-source: LCtrl (0x001D) ← CapsLock (0x003A),
# F13 (0x0064) ← LWin (0xE05B), F13 (0x0064) ← RWin (0xE05C).
$bytes = [byte[]](
  0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,
  0x04,0x00,0x00,0x00,
  0x1D,0x00,0x3A,0x00,
  0x64,0x00,0x5B,0xE0,
  0x64,0x00,0x5C,0xE0,
  0x00,0x00,0x00,0x00
)
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout' `
  -Name 'Scancode Map' -Value $bytes -Type Binary -Force

# ShareX personal folder. The default (Documents\ShareX) lands inside the
# OneDrive-redirected Documents folder, which Controlled Folder Access
# protects — the History.db SQLite open gets blocked and ShareX dies at
# startup (SQLite Error 14). LocalAppData is neither OneDrive-redirected nor
# CFA-protected. SystemOptions reads this HKCU override.
$sharex = 'HKCU:\SOFTWARE\ShareX'
if (-not (Test-Path $sharex)) {
  New-Item -Path $sharex -Force | Out-Null
}
Set-ItemProperty -Path $sharex `
  -Name 'PersonalPath' -Value "$env:LOCALAPPDATA\ShareX" -Type String -Force

# ShareX 21's region capture dies with Win32Exception 87 in RDP sessions
# created at a DPI other than the persisted system DPI, hence the forced
# process-wide DPI context.
if ($env:COMPUTERNAME -like 'LCSKVM*') {
  $layers = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
  if (-not (Test-Path $layers)) {
    New-Item -Path $layers -Force | Out-Null
  }
  Set-ItemProperty -Path $layers `
    -Name 'C:\Program Files\ShareX\ShareX.exe' -Value '~ HIGHDPIAWARE' -Type String -Force
}

# "Open with" entry routing text files into the WSL memo nvim. Registers the
# ProgID + per-extension OpenWithProgids only; Windows protects the default
# handler (UserChoice hash), so picking "always use" is a one-time manual step.
$memoProgId = 'HKCU:\SOFTWARE\Classes\NvimMemo'
$memoCmd = 'wscript.exe "{0}\.dotfiles\winget\run-hidden.vbs" "{0}\.dotfiles\winget\open-memo.ps1" "%1"' -f $env:USERPROFILE
if (-not (Test-Path "$memoProgId\shell\open\command")) {
  New-Item -Path "$memoProgId\shell\open\command" -Force | Out-Null
}
Set-ItemProperty -Path $memoProgId -Name '(default)' -Value 'Neovim Memo' -Force
Set-ItemProperty -Path "$memoProgId\shell\open\command" -Name '(default)' -Value $memoCmd -Force

foreach ($ext in '.txt', '.log', '.md', '.ini', '.cfg', '.conf', '.json', '.yaml', '.yml', '.xml', '.csv') {
  $owp = "HKCU:\SOFTWARE\Classes\$ext\OpenWithProgids"
  if (-not (Test-Path $owp)) {
    New-Item -Path $owp -Force | Out-Null
  }
  Set-ItemProperty -Path $owp -Name 'NvimMemo' -Value '' -Type String -Force
}
