# Creates a Startup-folder .lnk that runs $ExePath at login. Generic helper —
# tacky-borders, GlazeWM, and the winkey.ahk launcher all route through here.
# $Arguments is passed verbatim as the shortcut's command-line (quote any path
# with spaces at the call site). Idempotent (overwrites any existing .lnk).
param(
  [Parameter(Mandatory = $true)] [string]$ExePath,
  [Parameter(Mandatory = $true)] [string]$LinkPath,
  [string]$Arguments = ''
)

$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut($LinkPath)
$lnk.TargetPath = $ExePath
if ($Arguments) { $lnk.Arguments = $Arguments }
$lnk.WorkingDirectory = Split-Path -Parent $ExePath
$lnk.WindowStyle = 7
$lnk.Save()
