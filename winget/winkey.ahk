#Requires AutoHotkey v2.0
; `Ignore` (not `Force`): `Force` makes a new instance try to close the old
; one and pops "Could not close the previous instance of this script. Keep
; waiting?" when the close hangs (integrity mismatch / mid-hotkey / UIPI).
; `Ignore` makes the new instance silently exit if another is already running,
; so no modal ever. reload-ahk.ps1 is the sole arbiter of "exactly one AHK":
; it hard-kills all AHK + waits for exit + then starts fresh, so relying on
; AHK's own SingleInstance to resolve conflicts is unnecessary.
#SingleInstance Ignore

; --- Cold-boot diagnostic logging -------------------------------------------
; Records script start + periodic heartbeat + last hotkey fire timestamp to
; %TEMP%\winkey-debug.log. If TICK lines keep appearing but `lastHotkey` stays
; stale (or "never") while the user is pressing mapped keys, the WH_KEYBOARD_LL
; hook is dead even though the AHK process is healthy. AHK v2 has no
; A_KeybdHookInstalled (it's v1-only), so tracking `lastHotkey` from within
; each hotkey handler is the best proxy for hook liveness.
global lastHotkey := "never"
MarkHotkey(name) {
    global lastHotkey
    lastHotkey := name . "@" . FormatTime(, "HH:mm:ss")
}
DbgLog(tag) {
    global lastHotkey
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " tag " lastHotkey=" lastHotkey "`n", A_Temp . "\winkey-debug.log")
}
DbgLog("START script=" . A_ScriptFullPath . " ahk=" . A_AhkVersion)
SetTimer(DbgLog.Bind("TICK"), 10000)

; Cold-boot hook race: at logon the low-level keyboard hook installed by
; this script sometimes lands below Korean TSF / other services that are
; still initialising, and then stops firing for specific VKs (VK19/Hanja,
; Ctrl-inside-wezterm) even though the rest of the hotkeys work. Windows'
; LowLevelHooksTimeout (HKCU\Control Panel\Desktop) can also silently
; disable a hook that didn't respond fast enough during shell init.
;
; Fix: AHK's built-in InstallKeybdHook(Install:=true, Reinstall:=true)
; uninstalls and reinstalls the hook, which (a) repositions it at the top
; of the system hook chain and (b) clears any "system disabled this hook"
; state. Docs: https://www.autohotkey.com/docs/v2/lib/InstallKeybdHook.htm
; "If the system has stopped calling the hook because a program is not
; responding, reinstalling the hook can help get it running again."
;
; 5s delay gives the shell / TSF / IME time to settle before we reinstall.
; Historically we respawned the whole process on a 30s timer for this; the
; respawn model hit integrity mismatches (Force couldn't reap a Higher-
; integrity predecessor), and a built-in API turns out to be enough.
SetTimer(() => InstallKeybdHook(true, true), -5000)

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
; TaskbarCreated fires whenever Explorer (re)creates the shell — cold logon,
; explorer.exe restart, session switch. Reinstall the keyboard hook on the
; same signal so the same shell-settle race that motivates the 5s-post-init
; reinstall above also gets handled for mid-session Explorer restarts.
OnMessage(DllCall("RegisterWindowMessage", "Str", "TaskbarCreated", "UInt"),
    (*) => (HideShellTaskbars(), InstallKeybdHook(true, true)))

; Suppress Start Menu on lone Win press for keys the kernel remap does NOT
; cover: RWin is never remapped, and LWin only reaches here on machines
; without the Scancode Map (registry.ps1 not yet applied / pre-reboot).
; vkE8 (unassigned) injected between press and release breaks the sequence
; Windows listens for. `~` passes the Win key through.
~LWin::Send("{Blind}{vkE8}")
~RWin::Send("{Blind}{vkE8}")

; --- F13 IS the modifier (kernel Scancode Map) -------------------
; registry.ps1 remaps the physical Win key to F13 at the kernel, and glazewm
; binds f13+<key> DIRECTLY (config.yaml). No synthetic LWin is ever injected,
; so Windows never sees a Win modifier at all: Start menu, Win+P/N/L and
; every other native Win+<x> are structurally impossible — no per-key
; suppression needed. (An earlier revision re-materialized F13 as LWin here,
; which quietly resurrected all native Win behaviors; don't bring it back.)
; Under Citrix VDI the same property holds: the client forwards F13 and the
; local machine never sees Win — Win+L cannot lock the local session.
;
; AHK's own F13 combos below use `~F13 &` custom combinations: `~` keeps the
; F13 events flowing to glazewm's keyboard hook (a bare `F13 &` prefix would
; suppress them and kill every glazewm binding).

; --- Hyperkey: VK19 → Ctrl+Alt+F13 ----------------------------
; VK19 = VK_HANJA; on this Korean keyboard it's the physical key reporting
; that virtual code. Shift is kept OUT of hyper so `hyper+<k>` and
; `hyper+shift+<k>` are distinct bindings. F13 instead of LWin keeps the
; hyper chord Win-free (glazewm binds ctrl+alt+f13+<k>).
*VK19::(MarkHotkey("VK19"), Send("{Blind}{LCtrl down}{LAlt down}{F13 down}"))
*VK19 Up::Send("{Blind}{LCtrl up}{LAlt up}{F13 up}")

; Per-shortcut blocks — ONLY relevant on machines without the kernel remap
; (there, physical Win is a real Win key and these can mute native leftovers).
; On remapped machines no Win modifier ever exists, so nothing to block.
; Uncomment to disable. Prefixes: # Win  + Shift  ! Alt  ^ Ctrl
; Win+L/D/U/G are not blockable here (Windows processes them before AHK's
; hook); see winget/registry.ps1.

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
; F13 combos (physical Win+U/D/F after the kernel remap). `~F13 &` keeps F13
; flowing to glazewm's hook — see the F13 comment block above.
~F13 & u::(MarkHotkey("WinU"), CycleOnMonitor(1))
~F13 & d::(MarkHotkey("WinD"), CycleOnMonitor(-1))
; Win+F was glazewm's wm-cycle-focus, but that needs a focused window as
; anchor — no-op after switching monitors / closing the last focused app.
; Routing it through CycleOnMonitor removes the anchor requirement and
; also covers unmanaged windows like Win+U/D already do.
~F13 & f::CycleOnMonitor(1)

; --- Directional focus while a FLOATING window has focus -----------------
; glazewm's `focus --direction` is a no-op when the focused window is
; floating (verified live 2026-07-15: focus stays put), so Win+H/L felt
; dead inside Webex. The state-border daemon flags floating focus via
; %TEMP%\glazewm-float-focus.flag; only while it exists do these hotkeys
; activate — tiled focus keeps glazewm's native (zero-latency) handling.
;
; Custom combos fire on EVERY modifier variant, so shift is dispatched
; here too: plain = geometric nearest-window focus, shift = glazewm
; `move --direction` via CLI (floating move works natively there), plus
; the recenter pass for cross-DPI landings.
FloatNav(dx, dy) {
    active := WinExist("A")
    if !active
        return
    WinGetPos(&ax, &ay, &aw, &ah, active)
    acx := ax + aw / 2, acy := ay + ah / 2
    best := 0, bestDist := 0x7FFFFFFF
    for hwnd in WinGetList() {
        try {
            if (hwnd = active)
                continue
            if !DllCall("IsWindowVisible", "Ptr", hwnd)
                continue
            if WinGetMinMax(hwnd) = -1
                continue
            if WinGetTitle(hwnd) = ""
                continue
            if DllCall("GetWindowLongW", "Ptr", hwnd, "Int", -20, "Int") & 0x80  ; WS_EX_TOOLWINDOW
                continue
            ; Skip DWM-cloaked windows (glazewm hides other workspaces by
            ; cloaking; they'd otherwise be invisible-but-activatable here).
            cloaked := 0
            DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 14, "UInt*", &cloaked, "UInt", 4)
            if cloaked
                continue
            WinGetPos(&x, &y, &w, &h, hwnd)
            cx := x + w / 2, cy := y + h / 2
            if (dx != 0 && (cx - acx) * dx <= 20)  ; must lie in the direction
                continue
            if (dy != 0 && (cy - acy) * dy <= 20)
                continue
            dist := Abs(cx - acx) + Abs(cy - acy)
            if (dist < bestDist)
                bestDist := dist, best := hwnd
        }
    }
    if best
        WinActivate("ahk_id " best)
}
FloatKey(dir, dx, dy) {
    MarkHotkey("Float-" dir)
    if GetKeyState("Shift", "P") {
        gw := '"C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe"'
        RunWait(gw ' command move --direction ' dir, , 'Hide')
        mirror := EnvGet('DOTFILES_WIN')
        if mirror
            Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' mirror '\glazewm\recenter-floating.ps1"', , 'Hide')
        return
    }
    FloatNav(dx, dy)
}
#HotIf FileExist(A_Temp "\glazewm-float-focus.flag")
~F13 & h::FloatKey("left", -1, 0)
~F13 & j::FloatKey("down", 0, 1)
~F13 & k::FloatKey("up", 0, -1)
~F13 & l::FloatKey("right", 1, 0)
#HotIf

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
; 50ms timeout on every WM_IME_CONTROL send (AHK default is 5000ms): a
; foreground app with a busy message pump (Webex/CEF during meetings) makes
; SendMessage block, and while this script's thread is stuck its
; WH_KEYBOARD_LL callback can't run — Windows then stalls EVERY keystroke
; system-wide for up to LowLevelHooksTimeout (10s here). Symptom: all
; hotkeys feel seconds-slow whenever Webex holds focus. Timeout throws
; TimeoutError, which the existing catch treats as "unknown, skip tick".
IME_GetOpen(hWnd) {
    ime := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hWnd, "Ptr")
    try
        return SendMessage(0x283, 0x5, 0, , ime, , , , 50)  ; WM_IME_CONTROL, IMC_GETOPENSTATUS
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
        return SendMessage(0x283, 0x1, 0, , ime, , , , 50)
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
    try SendMessage(0x283, 0x6, state, , ime, , , , 50)     ; WM_IME_CONTROL, IMC_SETOPENSTATUS
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
