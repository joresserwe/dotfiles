#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon

changes := DllCall("FindFirstChangeNotificationW", "Str", A_ScriptDir, "Int", false,
    "UInt", 0x11, "Ptr") ; FILE_NAME | LAST_WRITE
if changes = -1
    ExitApp(1)
stdin := DllCall("GetStdHandle", "Int", -10, "Ptr")
count := 0
if !DllCall("ReadFile", "Ptr", stdin, "Ptr", Buffer(1), "UInt", 1, "UInt*", &count, "Ptr", 0) || !count
    ExitApp()
previous := ""
loop {
    ; A rename can signal before the writer releases its handle.
    loop 3 {
        try {
            state := Trim(FileRead(A_ScriptDir "\ime-state.txt", "UTF-8"))
            if (state = "KO" || state = "EN") {
                if state != previous {
                    FileAppend(state "`n", "*", "UTF-8-RAW")
                    previous := state
                }
                break
            }
        }
        if A_Index < 3
            Sleep(10)
    }
    loop {
        result := DllCall("WaitForSingleObject", "Ptr", changes, "UInt", 15000)
        ; Zebar's stdin pipe closes even when a forced restart skips pagehide.
        if !DllCall("PeekNamedPipe", "Ptr", stdin, "Ptr", 0, "UInt", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0)
            ExitApp()
        if result = 0
            break
        if result != 258 ; WAIT_TIMEOUT
            ExitApp(1)
    }
    if !DllCall("FindNextChangeNotification", "Ptr", changes)
        ExitApp(1)
}
