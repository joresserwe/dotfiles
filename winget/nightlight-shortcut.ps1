$wscript  = Join-Path $env:WINDIR 'System32\wscript.exe'
$mirror   = if ($env:DOTFILES_WIN) { $env:DOTFILES_WIN } else { Join-Path $env:USERPROFILE '.dotfiles' }
$programs = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$vbs    = Join-Path $mirror 'winget\run-hidden.vbs'
$action = Join-Path $mirror 'winget\nightlight.ps1'
if (-not (Test-Path $vbs) -or -not (Test-Path $action)) { exit 0 }

$ws  = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path $programs 'Night Light.lnk'))
$lnk.TargetPath   = $wscript
$lnk.Arguments    = ('"{0}" "{1}"' -f $vbs, $action)
$lnk.IconLocation = '{0},-26' -f (Join-Path $env:WINDIR 'System32\shell32.dll')
$lnk.Save()
Write-Host 'Night Light shortcut: applied'
