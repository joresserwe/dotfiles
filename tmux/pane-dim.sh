#!/usr/bin/env bash
set -euo pipefail

DIM_PERCENT=50 # brightness kept by dimmed colours

ANSI_BASE=(
  000000 cc5555 55cc55 cdcd55 5555cc cc55cc 7acaca cccccc
  555555 ff5555 55ff55 ffff55 5555ff ff55ff 55ffff ffffff
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

cmds=""
for ((i = 0; i < 256; i++)); do
  base_rgb "$i"
  printf -v dimmed '#%02x%02x%02x' \
    $((BASE_R * DIM_PERCENT / 100)) $((BASE_G * DIM_PERCENT / 100)) $((BASE_B * DIM_PERCENT / 100))
  cmds+="set -p \"pane-colours[$i]\" \"$dimmed\" ; "
done

tmux set-hook -g pane-focus-out "${cmds% ; }"
tmux set-hook -g pane-focus-in 'set -pu pane-colours'
