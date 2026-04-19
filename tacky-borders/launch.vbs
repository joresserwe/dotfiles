' Launcher for the 'tacky-borders' Scheduled Task (RunLevel=Highest).
'
' Why VBS / wscript and not a direct exe action?
'   tacky-borders has its own single-instance check that pops a modal
'   dialog ("an instance is already running; continue anyways?") when a
'   second instance sees the first's mutex still held. Task Scheduler's
'   MultipleInstances=StopExisting signals WM_CLOSE then launches the new
'   instance, but the old mutex outlives the signal race — so we'd hit the
'   dialog on every Hyper+C reload. Forcing taskkill+wait before launch
'   guarantees the old process is gone and the mutex released.
'
' Why not a PowerShell wrapper?
'   powershell.exe is a console-subsystem binary; even with -WindowStyle
'   Hidden a conhost flashes briefly at every reload (confirmed visually).
'   wscript.exe is GUI-subsystem — Windows never creates a console for it,
'   so there is nothing to flash.
'
' Invoked from the Scheduled Task action at UNC path (WSL dotfiles); lives
' in the repo so edits apply without re-registering the task.

Option Explicit
Dim shell
Set shell = CreateObject("WScript.Shell")

' Hidden taskkill /F + wait. shell.Run args: command, 0=SW_HIDE, True=wait.
shell.Run "taskkill /F /IM tacky-borders.exe", 0, True

' Brief pause so the mutex handle fully closes before the next instance
' re-acquires it. 400ms matches the reload-zebar.ps1 pattern.
WScript.Sleep 400

' Detached, hidden launch of the fresh instance (False = don't wait).
shell.Run """" & shell.ExpandEnvironmentStrings("%USERPROFILE%") & "\tacky-borders\tacky-borders.exe""", 0, False
