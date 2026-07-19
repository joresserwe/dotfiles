$wscript  = Join-Path $env:WINDIR 'System32\wscript.exe'
$mirror   = if ($env:DOTFILES_WIN) { $env:DOTFILES_WIN } else { Join-Path $env:USERPROFILE '.dotfiles' }
$programs = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$vbs  = Join-Path $mirror 'winget\open-terminal.vbs'
$icon = Join-Path $mirror 'winget\terminal.ico'
if (-not (Test-Path $vbs)) { exit 0 }

$ws  = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path $programs 'WSL-Terminal.lnk'))
$lnk.TargetPath   = $wscript
$lnk.Arguments    = ('"{0}"' -f $vbs)
$lnk.IconLocation = "$icon,0"
$lnk.Save()
Write-Host 'WSL-Terminal shortcut: applied'
