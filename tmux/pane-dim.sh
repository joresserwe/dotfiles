#!/usr/bin/env bash
set -euo pipefail

DIM_PERCENT=50 # brightness kept by dimmed colours

ANSI_BASE=(
  45475a f38ba8 a6e3a1 f9e2af 89b4fa f5c2e7 94e2d5 bac2de
  585b70 f38ba8 a6e3a1 f9e2af 89b4fa f5c2e7 94e2d5 a6adc8
)

CUBE_STEPS=(0 95 135 175 215 255)

base_rgb() { # colour index -> BASE_R / BASE_G / BASE_B (decimal)
  local i=$1
  if ((i < 16)); then
    local hex=${ANSI_BASE[i]}
    BASE_R=$((16#${hex:0:2})) BASE_G=$((16#${hex:2:2})) BASE_B=$((16#${hex:4:2}))
  elif ((i < 232)); then
    local n=$((i - 16))
    BASE_R=${CUBE_STEPS[n / 36]} BASE_G=${CUBE_STEPS[n / 6 % 6]} BASE_B=${CUBE_STEPS[n % 6]}
  else
    BASE_R=$((8 + (i - 232) * 10)) BASE_G=$BASE_R BASE_B=$BASE_R
  fi
}

DEFAULT_FG=cdd6f4 # must match the wt/tmux-profile.json scheme foreground

cmds=""
for ((i = 0; i < 256; i++)); do
  base_rgb "$i"
  printf -v dimmed '#%02x%02x%02x' \
    $((BASE_R * DIM_PERCENT / 100)) $((BASE_G * DIM_PERCENT / 100)) $((BASE_B * DIM_PERCENT / 100))
  cmds+="set -p \"pane-colours[$i]\" \"$dimmed\" ; "
done

# pane-colours only remaps the 256 indexed colours; text drawn with the
# default foreground bypasses the palette and needs window-style to dim.
printf -v dimmed_fg '#%02x%02x%02x' \
  $((16#${DEFAULT_FG:0:2} * DIM_PERCENT / 100)) \
  $((16#${DEFAULT_FG:2:2} * DIM_PERCENT / 100)) \
  $((16#${DEFAULT_FG:4:2} * DIM_PERCENT / 100))
cmds+="set -p window-style \"fg=$dimmed_fg\" ; "

tmux set-hook -g pane-focus-out "${cmds% ; }"
tmux set-hook -g pane-focus-in 'set -pu pane-colours ; set -pu window-style'
