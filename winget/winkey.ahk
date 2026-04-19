#Requires AutoHotkey v2.0
#SingleInstance Force

; At login the low-level keyboard hook can race the shell / user services
; initialization and land in a stale state — symptom is Hyper (and every
; other hook-based binding here) silently not firing after a cold boot.
; Self-relaunch 30s in so the hook reinstalls on a settled system. 3s was
; the original value but proved too short on this machine; Task Scheduler
; with a logon-delay was tried as an alternative but its launched process
; couldn't install the hook, so we stuck with Startup + a longer respawn.
; A_Args sentinel gates the guard: Startup auto-start runs without args and
; triggers it; the relaunched instance (and Hyper+C's reload-ahk.ps1) pass
; "reloaded" and skip it.
if A_Args.Length = 0 {
    SetTimer(() => Run(Format('"{1}" "{2}" reloaded', A_AhkPath, A_ScriptFullPath)), -30000)
}

; Reload signal for Hyper+C. ahk-reload.vbs touches the signal file; this
; timer polls for it and calls Reload() in-process. Using a signal file
; avoids #SingleInstance Force's "Could not close the previous script"
; dialog, which AHK pops up when the old instance is mid-hotkey (common on
; Hyper+C since Hanja is still being released while this fires).
reloadSignal := A_Temp "\winkey-reload.signal"
CheckReloadSignal() {
    global reloadSignal
    if FileExist(reloadSignal) {
        try FileDelete(reloadSignal)
        Reload()
    }
}
SetTimer(CheckReloadSignal, 500)

; --- Windows taskbar suppression ---------------------------------
; Hide Shell_TrayWnd (primary) + Shell_SecondaryTrayWnd (per extra monitor)
; because zebar already owns the tray/clock/workspace surface — a visible
; native taskbar is pure redundancy. SW_HIDE is a window-level hide, not a
; kill: explorer.exe, tray apps, Win+E, Start menu all keep working.
; Explorer broadcasts WM_TASKBARCREATED whenever it respawns (Windows
; Update, manual restart, session init race) and restores visibility on
; its own; the OnMessage hook re-hides on every broadcast so the taskbar
; never flashes back permanently. StuckRects3 auto-hide (registry.ps1)
; stays as a safety net — if this script dies the taskbar falls back to
; auto-hide rather than always-visible.
HideShellTaskbars() {
    for cls in ["Shell_TrayWnd", "Shell_SecondaryTrayWnd"] {
        for hwnd in WinGetList("ahk_class " cls)
            DllCall("ShowWindow", "Ptr", hwnd, "Int", 0)  ; SW_HIDE
    }
}
HideShellTaskbars()
OnMessage(DllCall("RegisterWindowMessage", "Str", "TaskbarCreated", "UInt"),
    (*) => HideShellTaskbars())

; Suppress Start Menu on lone Win press, while keeping Win+<key> combos alive.
; vkE8 (unassigned) injected between press and release breaks the sequence
; Windows listens for. `~` passes the Win key through so glazewm still sees it.
~LWin::Send("{Blind}{vkE8}")
~RWin::Send("{Blind}{vkE8}")

; --- Hyperkey: VK19 → Ctrl+Alt+Win ----------------------------
; VK19 = VK_HANJA; on this Korean keyboard it's the physical key reporting
; that virtual code. Shift is kept OUT of hyper so `hyper+<k>` and
; `hyper+shift+<k>` are distinct bindings. vkE8 on press breaks the lone-Win
; sequence so a bare tap doesn't open the Start menu.
*VK19::Send("{Blind}{LCtrl down}{LAlt down}{LWin down}{vkE8}")
*VK19 Up::Send("{Blind}{LCtrl up}{LAlt up}{LWin up}")

; Per-shortcut blocks. Uncomment to disable. Prefixes: # Win  + Shift  ! Alt  ^ Ctrl
; Skip keys bound by glazewm/config.yaml (#hjkl, #1-8, #n #p #z #m #f #space,
; #[ #] #= #-, their +shift variants where applicable, +s) — they'd
; override glazewm. Mode enter/exit/reload/pause use Hyper (Ctrl+Alt+Win+<k>).
; Win+L/D/U/G are not blockable here (Windows processes them before AHK's
; hook); see winget/registry.ps1. AHK hotkeys still layer on top — e.g.
; CycleOnMonitor below runs even with DisabledHotkeys=DU set.

;#a::return      ; Quick Settings
;#b::return      ; System tray focus
;#c::return      ; Copilot
;#e::return      ; File Explorer
;#i::return      ; Settings
;#k::return      ; Cast (wireless display)
;#o::return      ; Screen orientation lock
;#q::return      ; Search
;#r::return      ; Run dialog
;#t::return      ; Taskbar cycling
;#v::return      ; Clipboard history
;#w::return      ; Widgets
;#x::return      ; Power User menu
;#,::return      ; Peek at desktop
;#.::return      ; Emoji picker
;#Pause::return  ; System info

; --- Cycle focus on current monitor (Win+U / Win+D) ---------------
; Replaces glazewm's wm-cycle-focus because glazewm filters out certain
; windows at creation (Electron/cloaked apps like Raycast — see
; check_is_manageable in glazewm source) and can't reach them. Cycles
; all visible top-level windows on the focused monitor, unmanaged included.

; Bubble sort by hwnd, ascending. Used to give the cycle a stable order
; independent of z-order — otherwise WinGetList()'s z-ordered output
; shifts between presses (glazewm re-raises floating windows after every
; WinActivate), which made Win+U and Win+D traverse different subsets
; and allowed a floating window to repeat twice per Win+D revolution.
SortByHwnd(arr) {
    loop arr.Length - 1 {
        i := A_Index
        loop arr.Length - i {
            j := A_Index
            if arr[j] > arr[j + 1] {
                tmp := arr[j], arr[j] := arr[j + 1], arr[j + 1] := tmp
            }
        }
    }
}
CycleOnMonitor(dir) {
    ; "Current monitor" resolves from the active window; falls back to the
    ; cursor's monitor when nothing is focused (after monitor switch, app
    ; close, reload blip). Strictly monitor-scoped: never crosses to another
    ; monitor, so a single-window monitor no-ops. An earlier revision fell
    ; back to all-monitor cycling when the current monitor had <2 windows
    ; (to avoid a "silent no-op" for Win+F), but that leaked focus to the
    ; other monitor on Win+U/D and was the wrong default.
    active := WinExist("A")
    if active {
        curMon := DllCall("MonitorFromWindow", "Ptr", active, "UInt", 2, "Ptr")
    } else {
        pt := Buffer(8)
        DllCall("GetCursorPos", "Ptr", pt)
        curMon := DllCall("MonitorFromPoint", "Int64", NumGet(pt, 0, "Int64"), "UInt", 2, "Ptr")
    }
    winsMon := []
    for hwnd in WinGetList() {
        try {
            if !DllCall("IsWindowVisible", "Ptr", hwnd)
                continue
            if WinGetMinMax(hwnd) = -1  ; minimized
                continue
            if WinGetTitle(hwnd) = ""
                continue
            ; Skip tool/bar windows (zebar, tray widgets, etc.) — WS_EX_TOOLWINDOW
            ; is the standard "not in alt-tab, I'm a utility surface" flag, so
            ; filtering it covers these without per-app allowlisting.
            if DllCall("GetWindowLongW", "Ptr", hwnd, "Int", -20, "Int") & 0x80
                continue
            if DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr") = curMon
                winsMon.Push(hwnd)
        }
    }
    SortByHwnd(winsMon)
    ; No focus + at least one window on current (cursor) monitor → just grab
    ; it. This is the "zebar reload dropped focus, bring it back here" case.
    if !active && winsMon.Length >= 1 {
        WinActivate("ahk_id " winsMon[1])
        return
    }
    wins := winsMon
    if wins.Length < 2
        return
    idx := 0
    for i, h in wins
        if h = active {
            idx := i
            break
        }
    if !idx
        idx := 1
    next := Mod(idx - 1 + dir + wins.Length, wins.Length) + 1
    WinActivate("ahk_id " wins[next])
}
#u::CycleOnMonitor(1)
#d::CycleOnMonitor(-1)
; Win+F was glazewm's wm-cycle-focus, but that needs a focused window as
; anchor — no-op after switching monitors / closing the last focused app.
; Routing it through CycleOnMonitor removes the anchor requirement and
; also covers unmanaged windows like Win+U/D already do.
#f::CycleOnMonitor(1)

; --- wezterm IME workaround ---------------------------------------
; Windows wezterm's use_ime is always on and cannot be disabled, so
; the Korean IME swallows Ctrl+<letter> combos while in 한글 mode
; (e.g. Ctrl+ㅣ/ㅗ for pane nav). Force IME off on any Ctrl press
; inside wezterm. One-way (한글 → 영문): Ctrl-modified combos are
; control commands, not text, so losing 한글 composition is fine.
; The user's 한/영 key stays authoritative for normal typing.

; SendMessage is wrapped in try/catch because a higher-integrity foreground
; window (UAC prompt, elevated app the local process can't reach) makes UIPI
; block the WM_IME_CONTROL send and AHK throws OSError(5) "access denied".
; An uncaught throw from a timer-driven callback surfaces as a modal error
; dialog — which GlazeWM then tiles over the focused tile and steals the
; first wezterm redraw slot, so the newly launched wezterm never resizes
; to its cell. Returning -1 lets callers skip this tick silently.
IME_GetOpen(hWnd) {
    ime := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hWnd, "Ptr")
    try
        return SendMessage(0x283, 0x5, 0, , ime)  ; WM_IME_CONTROL, IMC_GETOPENSTATUS
    catch
        return -1
}

; --- IME state monitor for Zebar --------------------------------------
; Writes "KO" or "EN" to %TEMP%\ime-state.txt whenever the foreground
; window's IME open-status changes. Zebar polls the file to render the
; bar's IME badge. Adds ~0MB — reuses this same AHK process.
imeStateFile := A_Temp "\ime-state.txt"
lastImeState := ""

IME_GetConversionMode(hWnd) {
    ime := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hWnd, "Ptr")
    ; WM_IME_CONTROL + IMC_GETCONVERSIONMODE (0x001); reports IME_CMODE_NATIVE
    ; (0x0001) bit for Hangul vs Alphanumeric — reliable across Windows 11 TSF
    ; and legacy IMM IMEs, unlike IMC_GETOPENSTATUS which some TSF IMEs leave
    ; pinned to 1. Same UIPI guard as IME_GetOpen above.
    try
        return SendMessage(0x283, 0x1, 0, , ime)
    catch
        return -1
}

MonitorImeState() {
    global imeStateFile, lastImeState
    ; WinExist, not WinGetID — the timer fires during focus transitions
    ; (e.g. mid-Win+U cycle) when no window has "A" yet, and v2's WinGetID
    ; throws TargetError in that case while WinExist returns 0 cleanly.
    hwnd := WinExist("A")
    if !hwnd
        return
    mode := IME_GetConversionMode(hwnd)
    if mode = -1  ; UIPI-blocked this tick; leave lastImeState as-is
        return
    state := (mode & 0x1) ? "KO" : "EN"
    if state != lastImeState {
        lastImeState := state
        try FileDelete(imeStateFile)
        try FileAppend(state, imeStateFile)
    }
}
SetTimer(MonitorImeState, 250)

IME_SetOpen(hWnd, state) {
    ime := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hWnd, "Ptr")
    try SendMessage(0x283, 0x6, state, , ime)     ; WM_IME_CONTROL, IMC_SETOPENSTATUS
}

#HotIf WinActive("ahk_exe wezterm-gui.exe")
~LCtrl::
~RCtrl::
{
    hWnd := WinGetID("A")
    ; IME_GetOpen returns -1 when UIPI blocks the probe; treat that as
    ; "unknown, don't touch" rather than truthy-so-toggle.
    if IME_GetOpen(hWnd) = 1
        IME_SetOpen(hWnd, 0)
}
#HotIf
