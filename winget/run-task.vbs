Option Explicit
Dim svc
If WScript.Arguments.Count < 1 Then WScript.Quit 1
Set svc = CreateObject("Schedule.Service")
svc.Connect
svc.GetFolder("\").GetTask(WScript.Arguments(0)).Run Null
