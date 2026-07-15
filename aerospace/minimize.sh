#!/usr/bin/env bash
# alt-shift-m — minimize the focused window, recording it so alt-shift-z
# (restore-min.sh) can bring windows back most-recent-first.
#
# macOS has no decent built-in restore for minimized windows (Dock click or
# the Cmd+Tab-hold-Option trick only), so this mirrors the Windows pair
# glazewm/minimize-window.ps1 + restore-window.ps1 (f13+shift+m / z).
# Accessibility (System Events) permission is already a prerequisite of this
# config — the floating move/resize bindings use the same mechanism.
#
# NOTE: written on the Windows side for parity, NOT yet tested on a real
# mac. Window identity is process name + title (macOS AX windows have no
# stable ids), so title-churning apps fall back to any minimized window of
# the same app on restore.

stack="${TMPDIR:-/tmp}/aerospace-minimize-stack.txt"

info=$(osascript -e '
tell application "System Events"
  set p to first process whose frontmost is true
  set w to window 1 of p
  set out to (name of p) & linefeed & (name of w)
  set value of attribute "AXMinimized" of w to true
  return out
end tell' 2>/dev/null) || exit 0

# One stack line per window: "process<US>title" (US = 0x1f separator).
printf '%s\n' "${info//$'\n'/$'\x1f'}" >> "$stack"
