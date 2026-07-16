#!/usr/bin/env bash
# Claude Code statusline — compact 1-line style (macOS/WSL port of statusline.ps1)
# model + effort | folder | git branch/status | context bar (color-coded) | cost | duration | rate limits
# Requires jq (installed via Brewfile on both macOS and WSL). Keep visually in
# sync with claude/statusline.ps1 — the Windows side can't assume jq/node/python.

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
[[ -n "$input" ]] || exit 0

E=$'\e'
R="${E}[0m"
SEP=" ${E}[38;5;238m│${R} "

j() { printf '%s' "$input" | jq -r "$1" 2>/dev/null; }

model="$(j '.model.display_name // empty')"
line="${E}[1;38;5;141m🤖 ${model}${R}"
effort="$(j '.effort.level // empty')"
[[ -n "$effort" ]] && line+=" ${E}[38;5;221m⚡${effort}${R}"

cwd="$(j '.workspace.current_dir // empty')"
dir="${cwd##*/}"
line+="${SEP}${E}[38;5;75m📁 ${dir}${R}"

branch="$(git -C "$cwd" branch --show-current 2>/dev/null)"
if [[ -n "$branch" ]]; then
  staged=0 modified=0 untracked=0
  while IFS= read -r l; do
    [[ ${#l} -lt 2 ]] && continue
    if [[ "${l:0:1}" == "?" ]]; then untracked=$((untracked+1)); continue; fi
    [[ "${l:0:1}" != " " ]] && staged=$((staged+1))
    [[ "${l:1:1}" != " " ]] && modified=$((modified+1))
  done < <(git -C "$cwd" status --porcelain 2>/dev/null)
  g="${E}[38;5;114m🌿 ${branch}${R}"
  (( staged ))    && g+=" ${E}[38;5;114m●${staged}${R}"
  (( modified ))  && g+=" ${E}[38;5;221m~${modified}${R}"
  (( untracked )) && g+=" ${E}[38;5;245m?${untracked}${R}"
  line+="${SEP}${g}"
fi

pct="$(j '.context_window.used_percentage // 0 | floor')"
if   (( pct >= 85 )); then barColor='38;5;203'
elif (( pct >= 60 )); then barColor='38;5;221'
else                       barColor='38;5;114'; fi
width=10
filled=$(( pct * width / 100 )); (( filled > width )) && filled=$width
bar=""
for ((i = 0; i < filled; i++)); do bar+='█'; done
for ((i = filled; i < width; i++)); do bar+='░'; done

used_tok="$(j '((.context_window.total_input_tokens // 0) / 1000) | round')"
size_tok="$(j '((.context_window.context_window_size // 0) / 1000) | round')"
line+="${SEP}🧠 ${E}[${barColor}m${bar}${R} ${E}[1m${pct}%${R} ${E}[38;5;245m(${used_tok}k/${size_tok}k)${R}"

cost="$(j '.cost.total_cost_usd // 0')"
line+="${SEP}💰 ${E}[38;5;221m\$$(printf '%.2f' "$cost")${R}"

ms="$(j '.cost.total_duration_ms // 0 | floor')"
total_min=$(( ms / 60000 )); h=$(( total_min / 60 )); m=$(( total_min % 60 ))
if (( h > 0 )); then dur="${h}h ${m}m"; else dur="${m}m"; fi
line+="${SEP}⏱️ ${E}[38;5;245m${dur}${R}"

rl_color() {
  if   (( $1 >= 80 )); then printf '38;5;203'
  elif (( $1 >= 50 )); then printf '38;5;221'
  else                      printf '38;5;114'; fi
}
rl=()
p5="$(j '.rate_limits.five_hour.used_percentage // empty | round')"
[[ -n "$p5" ]] && rl+=("${E}[38;5;245m5h${R}${E}[$(rl_color "$p5")m${p5}%${R}")
p7="$(j '.rate_limits.seven_day.used_percentage // empty | round')"
[[ -n "$p7" ]] && rl+=("${E}[38;5;245m7d${R}${E}[$(rl_color "$p7")m${p7}%${R}")
if (( ${#rl[@]} )); then
  dot="${E}[38;5;238m·${R}"
  joined="${rl[0]}"
  for ((i = 1; i < ${#rl[@]}; i++)); do joined+="${dot}${rl[i]}"; done
  line+="${SEP}${joined}"
fi

printf '%s\n' "$line"
