#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

seconds := A_Args.Length ? Integer(A_Args[1]) : 30
encoded := Trim(FileOpen("*", "r", "UTF-8-RAW").ReadLine(), " `r`n")
size := 0
if !DllCall("crypt32\CryptStringToBinaryW", "Str", encoded, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", &size, "Ptr", 0, "Ptr", 0) || !size
    ExitApp(1)
secret := Buffer(size)
DllCall("crypt32\CryptStringToBinaryW", "Str", encoded, "UInt", 0, "UInt", 1, "Ptr", secret, "UInt*", &size, "Ptr", 0, "Ptr", 0)
encoded := ""

Wipe(*) {
    DllCall("RtlZeroMemory", "Ptr", secret, "UPtr", secret.Size)
}
OnExit(Wipe)
SetTimer(() => ExitApp(), -seconds * 1000)
FileAppend("ready`n", "*", "UTF-8-RAW")

#HotIf GetKeyState("F13") && GetKeyState("Ctrl") && GetKeyState("Alt")
*v:: {
    loop 60 {
        if !(GetKeyState("F13") || GetKeyState("Ctrl") || GetKeyState("Alt") || GetKeyState("v", "P"))
            break
        Sleep(50)
    }
    if GetKeyState("F13") || GetKeyState("Ctrl") || GetKeyState("Alt")
        return
    SendText(StrGet(secret, size, "UTF-8"))
}
#HotIf
~Esc::ExitApp()
