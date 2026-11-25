# lib/common.sh — shared functions for install.sh (macOS) and install.linux.sh (WSL/Ubuntu).
# This file is SOURCED, never executed. No top-level side effects. Mode 644.

# Refuse direct execution.
if { [ -n "${BASH_VERSION:-}" ] && [ "${BASH_SOURCE[0]}" = "$0" ]; } ||
   { [ -n "${ZSH_VERSION:-}" ] && [ "$ZSH_EVAL_CONTEXT" = toplevel ]; }; then
  echo "lib/common.sh is a library; source it instead of executing." >&2
  exit 1
fi

# detect_os → echoes "darwin" or "linux"
detect_os() {
  case "$(uname -s)" in
    Darwin) echo darwin ;;
    Linux)  echo linux ;;
    *)      echo unknown ;;
  esac
}

# dotfiles_profile → echoes "light" or "full" (env DOTFILES_PROFILE, then
# $XDG_STATE_HOME/dotfiles/profile, defaulting to "full")
dotfiles_profile() {
  local p="${DOTFILES_PROFILE:-}"
  if [ "$p" != "light" ] && [ "$p" != "full" ]; then
    p="$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/profile" 2>/dev/null || true)"
  fi
  case "$p" in
    light) echo light ;;
    *)     echo full ;;
  esac
}

# install_claude_settings → links claude/settings.json on --full; on --light
# writes a regular file with prefersReducedMotion=true so git stays clean.
install_claude_settings() {
  local managed="$DOTFILES_PATH/claude/settings.json"
  local target="${XDG_DATA_HOME:-$HOME/.local/share}/claude/settings.json"
  local profile merged tmp
  profile="$(dotfiles_profile)"

  mkdir -p "$(dirname "$target")"
  if [ "$profile" = "light" ]; then
    if [ -f "$target" ]; then
      merged="$(jq -s '.[1] + (.[0] | {model, effortLevel, modelSettings} | with_entries(select(.value != null))) + {prefersReducedMotion: true}' "$target" "$managed")" || return 1
    else
      merged="$(jq '. + {prefersReducedMotion: true}' "$managed")" || return 1
    fi
    if [ ! -L "$target" ] && [ -f "$target" ] && jq -e --argjson want "$merged" '. == $want' "$target" >/dev/null; then
      log_skip "claude settings already up to date (light): $target"
      return 0
    fi
    tmp="$target.tmp.$$"
    printf '%s\n' "$merged" > "$tmp" && mv "$tmp" "$target" || return 1
    log_done "claude settings rendered (light: prefersReducedMotion=true): $target"
  else
    create_link "$managed" "$target"
  fi
}

configure_git_filters() {
  git -C "$DOTFILES_PATH" config filter.strip-claude-model.clean 'sh claude/settings-filter.sh clean'
  git -C "$DOTFILES_PATH" config filter.strip-claude-model.smudge 'sh claude/settings-filter.sh smudge'
}

log_step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
log_skip() { printf '    \033[2;37m-- %s\033[0m\n' "$*"; }
log_done() { printf '    \033[1;32mok\033[0m %s\n' "$*"; }

MANUAL_STEPS=()

add_manual() { MANUAL_STEPS+=("$*"); }

log_manual() {
  printf '    \033[1;33m!!\033[0m %s\n' "$*"
  add_manual "$*"
}

print_manual_steps() {
  local item
  [ "${#MANUAL_STEPS[@]}" -gt 0 ] || return 0
  printf '\n\033[1;33m==> Left for you to do (%d)\033[0m\n' "${#MANUAL_STEPS[@]}"
  for item in "${MANUAL_STEPS[@]}"; do
    printf '    \033[1;33m!!\033[0m %s\n' "$item"
  done
}

# ensure_dir path... → mkdir -p with idempotent log
ensure_dir() {
  for dir in "$@"; do
    if [ -d "$dir" ]; then
      log_skip "exists: $dir"
    else
      mkdir -p "$dir"
      log_done "created: $dir"
    fi
  done
}

# update_repo dir → ff-only pull an existing clone. Non-fatal: an installer
# re-run must survive offline machines, dirty trees, and diverged histories.
update_repo() {
  local dir="$1"
  if git -C "$dir" pull --ff-only --quiet 2>/dev/null; then
    log_done "updated: $dir"
  else
    log_skip "update skipped (offline/dirty/diverged): $dir"
  fi
}

# create_link target link_path → mkdir -p parent, then ln -sf
create_link() {
  local target_file="$1"
  local link_path="$2"
  local link_dir
  link_dir="$(dirname "$link_path")"
  [ -d "$link_dir" ] || mkdir -p "$link_dir"
  ln -sf "$target_file" "$link_path"
  log_done "link: $link_path -> $target_file"
}

install_codex_web_guidance() {
  local cli="$HOME/.local/bin/codex" catalogs source_url plugins
  catalogs="$("$cli" plugin marketplace list --json)" || return 1
  source_url="$(jq -r '.marketplaces[] | select(.name == "googlechrome") | .marketplaceSource.source // "local"' <<< "$catalogs")" || return 1
  case "$source_url" in
    "") "$cli" plugin marketplace add GoogleChrome/modern-web-guidance || return 1 ;;
    https://github.com/GoogleChrome/modern-web-guidance.git) ;;
    *) printf 'googlechrome already points to a different source: %s\n' "$source_url" >&2; return 1 ;;
  esac
  plugins="$("$cli" plugin list --marketplace googlechrome --json)" || return 1
  if ! jq -e 'any(.installed[]; .pluginId == "modern-web-guidance@googlechrome")' <<< "$plugins" >/dev/null; then
    "$cli" plugin add modern-web-guidance@googlechrome
  fi
}

_agy_same_link() {
  local source="$1" target="$2" source_real target_link target_real
  source_real="$(CDPATH= cd -- "$(dirname "$source")" && pwd)/$(basename "$source")"
  target_link="$(readlink "$target")" || return 1
  case "$target_link" in
    /*) target_real="$target_link" ;;
    *)  target_real="$(CDPATH= cd -- "$(dirname "$target")" && pwd)/$target_link" ;;
  esac
  [ "$target_real" = "$source_real" ]
}

_agy_backup() {
  local path="$1" stamp backup index=0
  stamp="$(date +%Y%m%d%H%M%S)"
  backup="$path.agy-backup-$stamp-$$"
  while [ -e "$backup" ] || [ -L "$backup" ]; do
    index=$((index + 1))
    backup="$path.agy-backup-$stamp-$$-$index"
  done
  mv "$path" "$backup"
  log_done "agy backup: $path -> $backup"
}

_agy_link_file() {
  local source="$1" target="$2"
  [ -f "$source" ] || return 1
  mkdir -p "$(dirname "$target")"
  if [ -L "$target" ]; then
    _agy_same_link "$source" "$target" && return 0
    _agy_backup "$target"
  elif [ -e "$target" ]; then
    if [ -d "$target" ]; then
      log_skip "agy preserved directory: $target"
      return 0
    fi
    _agy_backup "$target"
  fi
  ln -s "$source" "$target"
  log_done "link: $target -> $source"
}

_agy_link_skill() {
  local source="$1" target="$2"
  [ -d "$source" ] || return 1
  mkdir -p "$(dirname "$target")"
  if [ -L "$target" ]; then
    _agy_same_link "$source" "$target" && return 0
    _agy_backup "$target"
  elif [ -e "$target" ]; then
    log_skip "agy preserved existing skill entry: $target"
    return 0
  fi
  ln -s "$source" "$target"
  log_done "link: $target -> $source"
}

install_antigravity() {
  local cli="$HOME/.local/bin/agy"
  local managed="$DOTFILES_PATH/antigravity/settings.json"
  local target="$HOME/.gemini/antigravity-cli/settings.json"
  local config_dir="${ANTIGRAVITY_CONFIG_DIR:-$HOME/.gemini/config}"
  local profile light_speed merged tmp skill_dir skill_name plugins

  profile="$(dotfiles_profile)"
  light_speed="medium"
  [ "$profile" = "light" ] && light_speed="off"

  if [ -x "$cli" ]; then
    log_skip "agy CLI already installed (self-updates)"
  else
    curl -fsSL https://antigravity.google/cli/install.sh | bash || return 1
    log_done "agy CLI installed: $cli"
  fi

  # agy rewrites settings.json via atomic replace (and normalizes it at
  # startup), which would sever a symlink. Merge the managed keys into the
  # machine-local file instead so /config and /model choices survive.
  # The terminal sandbox rejects non-absolute ~/ paths and path globs
  # (e.g. ~/.ssh/id_*) in read_file/write_file rules; normalize both here
  # while keeping the repo file portable.
  local expand_home_jq='
    def expand_home($h):
      if type == "string" then
        (if startswith("read_file(~/") then "read_file(" + $h + "/" + .[12:]
         elif startswith("write_file(~/") then "write_file(" + $h + "/" + .[13:]
         elif . == "read_file(~)" then "read_file(" + $h + ")"
         elif . == "write_file(~)" then "write_file(" + $h + ")"
         else . end)
        | if . == ("read_file(" + $h + "/.ssh/id_*)") then "read_file(" + $h + "/.ssh)"
          else . end
      else . end;
  '
  mkdir -p "$(dirname "$target")"
  if [ -f "$target" ]; then
    merged="$(jq -s --arg speed "$light_speed" --arg home "${HOME%/}" "
      $expand_home_jq
      .[0] as \$cur | .[1] as \$mgd | (\$cur * \$mgd)
      | .runningLightSpeed = \$speed
      | if ((\$mgd.permissions // null) | type) == \"object\" then
          .permissions.allow = (((\$cur.permissions.allow // []) + (\$mgd.permissions.allow // [])) | map(expand_home(\$home)) | unique)
          | .permissions.ask = (((\$cur.permissions.ask // []) + (\$mgd.permissions.ask // [])) | map(expand_home(\$home)) | unique)
          | .permissions.deny = (((\$cur.permissions.deny // []) + (\$mgd.permissions.deny // [])) | map(expand_home(\$home)) | unique)
        else . end
    " "$target" "$managed")" || return 1
    if jq -e --argjson want "$merged" '. == $want' "$target" >/dev/null; then
      log_skip "agy settings already up to date: $target"
    else
      tmp="$target.tmp.$$"
      (umask 077 && printf '%s\n' "$merged" > "$tmp") && mv "$tmp" "$target" || return 1
      log_done "agy settings merged ($profile: runningLightSpeed=$light_speed): $target"
    fi
  else
    merged="$(jq --arg speed "$light_speed" --arg home "${HOME%/}" "
      $expand_home_jq
      .runningLightSpeed = \$speed
      | if ((.permissions // null) | type) == \"object\" then
          .permissions.allow = ((.permissions.allow // []) | map(expand_home(\$home)) | unique)
          | .permissions.ask = ((.permissions.ask // []) | map(expand_home(\$home)) | unique)
          | .permissions.deny = ((.permissions.deny // []) | map(expand_home(\$home)) | unique)
        else . end
    " "$managed")" || return 1
    tmp="$target.tmp.$$"
    (umask 077 && printf '%s\n' "$merged" > "$tmp") && mv "$tmp" "$target" || return 1
    log_done "agy settings merged ($profile: runningLightSpeed=$light_speed): $target"
  fi

  local managed_mcp="$DOTFILES_PATH/antigravity/mcp_config.json"
  local target_mcp="$config_dir/mcp_config.json"
  local merged_mcp chrome_mcp=""
  [ -n "${WSL_DISTRO_NAME:-}" ] && chrome_mcp="$DOTFILES_PATH/wsl/chrome-mcp.sh"

  mkdir -p "$config_dir/skills"
  _agy_link_file "$DOTFILES_PATH/antigravity/AGENTS.md" "$config_dir/AGENTS.md" || return 1
  _agy_link_file "$DOTFILES_PATH/antigravity/hooks.json" "$config_dir/hooks.json" || return 1

  # agy mcp mutates mcp_config.json via atomic replace, which would sever a symlink.
  if [ -f "$managed_mcp" ]; then
    local mcp_merge_jq='
      ($mgd.mcpServers // {})
      | if ($chrome_mcp | length) > 0 then
          . + { "chrome-devtools": { "command": $chrome_mcp, "disabled": false } }
        else . end
      | to_entries
      | map(
          .key as $k
          | (($cur.mcpServers // {})[$k] // null) as $prev
          | .value = (
              .value
              | if ($prev != null and ($prev.disabled | type) == "boolean") then
                  .disabled = $prev.disabled
                elif (.disabled | type) != "boolean" then
                  .disabled = false
                else . end
            )
        )
      | from_entries as $next_servers
      | ($cur * { mcpServers: (($cur.mcpServers // {}) + $next_servers) })
    '
    if [ -f "$target_mcp" ]; then
      merged_mcp="$(jq -s --arg chrome_mcp "$chrome_mcp" ".[0] as \$cur | .[1] as \$mgd | $mcp_merge_jq" "$target_mcp" "$managed_mcp")" || return 1
      if jq -e --argjson want "$merged_mcp" '. == $want' "$target_mcp" >/dev/null; then
        log_skip "agy mcp_config already up to date: $target_mcp"
      else
        tmp="$target_mcp.tmp.$$"
        (umask 077 && printf '%s\n' "$merged_mcp" > "$tmp") && mv "$tmp" "$target_mcp" || return 1
        log_done "agy mcp_config merged: $target_mcp"
      fi
    else
      merged_mcp="$(jq --arg chrome_mcp "$chrome_mcp" "{} as \$cur | . as \$mgd | $mcp_merge_jq" "$managed_mcp")" || return 1
      tmp="$target_mcp.tmp.$$"
      (umask 077 && printf '%s\n' "$merged_mcp" > "$tmp") && mv "$tmp" "$target_mcp" || return 1
      log_done "agy mcp_config created: $target_mcp"
    fi
  fi

  for skill_dir in "$DOTFILES_PATH"/antigravity/skills/*; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    _agy_link_skill "$skill_dir" "$config_dir/skills/$skill_name" || return 1
  done

  plugins="$("$cli" plugin list --json 2>/dev/null)" || plugins="[]"
  if [ -d "$config_dir/plugins/modern-web-guidance" ] \
    || jq -e 'any(.[]; ((.name // .id // .dir // "") | test("modern-web-guidance")))' <<< "$plugins" >/dev/null 2>&1; then
    log_skip "agy plugin already installed: modern-web-guidance"
  else
    "$cli" plugin install https://github.com/GoogleChrome/modern-web-guidance || return 1
    log_done "agy plugin installed: modern-web-guidance"
  fi
}
