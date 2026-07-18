# Start Menu is what launcher search (Raycast, Flow, Start, Win+R) indexes —
# the .lnk files must live there for these to be launchable by name without
# launcher-side configuration.

$wt = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
if (-not (Test-Path $wt)) { exit 0 }

$mirror = if ($env:DOTFILES_WIN) { $env:DOTFILES_WIN } else { Join-Path $env:USERPROFILE '.dotfiles' }
$programs = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'

# The wt.exe execution alias is a reparse point with no icon resource, and
# the real package exe under WindowsApps renders blank — its folder ACL
# blocks Explorer's icon extraction (and the path is version-pinned).
$shortcuts = @(
    @{ Name = 'Terminal'
       Args = '-f -p Terminal'
       Icon = (Join-Path $mirror 'winget\terminal.ico') + ',0' },
    @{ Name = 'yazi'
       Args = '-w new -f nt -p Terminal wsl.exe -d Ubuntu --cd ~ -e /usr/bin/zsh -lic yazi'
       Icon = (Join-Path $mirror 'winget\yazi.ico') + ',0' }
)

$ws = New-Object -ComObject WScript.Shell
foreach ($s in $shortcuts) {
    $lnk = $ws.CreateShortcut((Join-Path $programs ($s.Name + '.lnk')))
    $lnk.TargetPath = $wt
    $lnk.Arguments = $s.Args
    if ($s.Icon) { $lnk.IconLocation = $s.Icon }
    $lnk.Save()
}
Write-Host 'wt-shortcuts: applied'
