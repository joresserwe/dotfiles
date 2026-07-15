' Zero-flash launcher for PowerShell scripts run by Scheduled Tasks.
'
' powershell.exe (and cmd.exe) are console-subsystem binaries: even with
' -WindowStyle Hidden, a conhost — or a full Windows Terminal window on
' Windows 11 — flashes for a moment when Task Scheduler starts them at
' logon. wscript.exe is GUI-subsystem, so no console is ever allocated;
' it spawns powershell already SW_HIDEd. Same pattern as
' tacky-borders/launch.vbs, generalized.
'
' Usage: wscript.exe run-hidden.vbs <script.ps1> [args...]
'
' Note: shell.Run(..., 0, False) detaches — the task finishes as soon as
' wscript exits, so task-level ExecutionTimeLimit / StopExisting do not
' reach the spawned PowerShell. Every script launched this way must
' self-terminate (all of ours do).

Option Explicit
Dim shell, cmd, i
If WScript.Arguments.Count < 1 Then WScript.Quit 1
Set shell = CreateObject("WScript.Shell")
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & WScript.Arguments(0) & """"
For i = 1 To WScript.Arguments.Count - 1
  cmd = cmd & " """ & WScript.Arguments(i) & """"
Next
shell.Run cmd, 0, False
