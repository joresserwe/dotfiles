# Creates a Startup-folder .lnk pointing at tacky-borders.exe so the app
# launches on login. Invoked by install.linux.sh; idempotent (overwrites).
param(
  [Parameter(Mandatory = $true)] [string]$ExePath,
  [Parameter(Mandatory = $true)] [string]$LinkPath
)

$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut($LinkPath)
$lnk.TargetPath = $ExePath
$lnk.WorkingDirectory = Split-Path -Parent $ExePath
$lnk.WindowStyle = 7
$lnk.Save()
