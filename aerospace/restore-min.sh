#!/usr/bin/env bash
# alt-shift-z — restore the most recently minimized window (stack written by
# minimize.sh, repeatable), falling back to the first minimized window of
# any app for windows minimized via Cmd+M / the yellow button.
#
# NOTE: written on the Windows side for parity with glazewm/restore-window.ps1
# (f13+shift+z), NOT yet tested on a real mac.

stack="${TMPDIR:-/tmp}/aerospace-minimize-stack.txt"

try_restore() {  # $1 = process name, $2 = window title ("" = any minimized)
  osascript - "$1" "$2" <<'OSA' 2>/dev/null
on run argv
  set pname to item 1 of argv
  set wtitle to item 2 of argv
  tell application "System Events"
    if not (exists process pname) then return "no"
    repeat with w in windows of process pname
      try
        if value of attribute "AXMinimized" of w is true then
          if wtitle is "" or name of w is wtitle then
            set value of attribute "AXMinimized" of w to false
            set frontmost of process pname to true
            return "ok"
          end if
        end if
      end try
    end repeat
  end tell
  return "no"
end run
OSA
}

if [[ -f "$stack" ]]; then
  while [[ -s "$stack" ]]; do
    last=$(tail -n 1 "$stack")
    sed -i '' -e '$d' "$stack"
    proc="${last%%$'\x1f'*}"
    title="${last#*$'\x1f'}"
    [[ "$(try_restore "$proc" "$title")" == "ok" ]] && exit 0
    # Title changed while minimized — any minimized window of the same app.
    [[ "$(try_restore "$proc" "")" == "ok" ]] && exit 0
    # Stale entry (window/app gone) — keep popping.
  done
fi

# Fallback: first minimized window of any regular app.
osascript <<'OSA' 2>/dev/null
tell application "System Events"
  repeat with p in (processes whose background only is false)
    repeat with w in windows of p
      try
        if value of attribute "AXMinimized" of w is true then
          set value of attribute "AXMinimized" of w to false
          set frontmost of p to true
          return
        end if
      end try
    end repeat
  end repeat
end tell
OSA
