#!/usr/bin/env bash
# Install only the Codex files owned by this repository.
# This script deliberately does not install or update the rest of the dotfiles.
set -Eeuo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
default_codex_home="$HOME/.codex"
xdg_codex_home="$xdg_data_home/codex"
managed_config="$repo_root/codex/config.toml"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

log() {
  printf 'codex: %s\n' "$*"
}

backup_path() {
  local path="$1"
  local stamp backup index
  stamp="$(date +%Y%m%d%H%M%S)"
  backup="$path.codex-backup-$stamp-$$"
  index=0
  while [ -e "$backup" ] || [ -L "$backup" ]; do
    index=$((index + 1))
    backup="$path.codex-backup-$stamp-$$-$index"
  done
  mv "$path" "$backup"
  log "backed up $path -> $backup"
}

same_link_target() {
  local source="$1"
  local target="$2"
  local source_real target_link target_real

  source_real="$(CDPATH= cd -- "$(dirname "$source")" && pwd)/$(basename "$source")"
  target_link="$(readlink "$target")"
  case "$target_link" in
    /*) target_real="$target_link" ;;
    *) target_real="$(CDPATH= cd -- "$(dirname "$target")" && pwd)/$target_link" ;;
  esac
  [ "$target_real" = "$source_real" ]
}

link_file() {
  local source="$1"
  local target="$2"

  [ -f "$source" ] || die "missing source file: $source"
  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ]; then
    if same_link_target "$source" "$target"; then
      return 0
    fi
    backup_path "$target"
  elif [ -e "$target" ]; then
    if [ -d "$target" ]; then
      log "preserved directory at $target"
      return 0
    fi
    backup_path "$target"
  fi

  ln -s "$source" "$target"
  log "linked $target -> $source"
}

link_skill() {
  local source="$1"
  local target="$2"

  [ -d "$source" ] || die "missing skill directory: $source"
  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ]; then
    if same_link_target "$source" "$target"; then
      return 0
    fi
    backup_path "$target"
  elif [ -e "$target" ]; then
    # Never replace a real skills directory: system and user skills may live there.
    log "preserved existing skill directory $target"
    return 0
  fi

  ln -s "$source" "$target"
  log "linked $target -> $source"
}

sync_config() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  python3 - "$managed_config" "$target" <<'PY'
import copy
import datetime as dt
import json
import math
import os
import re
import stat
import sys
import tempfile
import time
import tomllib
from pathlib import Path

managed_path = Path(sys.argv[1])
target = Path(sys.argv[2])

try:
    with managed_path.open("rb") as handle:
        managed = tomllib.load(handle)
except (OSError, tomllib.TOMLDecodeError) as exc:
    raise SystemExit(f"cannot parse managed config {managed_path}: {exc}")

existing = {}
if target.exists() or target.is_symlink():
    try:
        with target.open("rb") as handle:
            existing = tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise SystemExit(f"cannot parse existing config {target}: {exc}")

def is_own_comment_handler(handler):
    return (
        isinstance(handler, dict)
        and isinstance(handler.get("command"), str)
        and "codex/hooks/comment-check.py" in handler["command"]
    )

def merge_post_tool_use(old, new):
    result = []
    for item in old:
        if not isinstance(item, dict) or not isinstance(item.get("hooks"), list):
            result.append(copy.deepcopy(item))
            continue
        kept_handlers = [handler for handler in item["hooks"] if not is_own_comment_handler(handler)]
        if kept_handlers:
            cleaned = copy.deepcopy(item)
            cleaned["hooks"] = kept_handlers
            result.append(cleaned)
    result.extend(copy.deepcopy(new))
    return result

def overlay(old, new):
    if not isinstance(old, dict) or not isinstance(new, dict):
        return copy.deepcopy(new)
    result = copy.deepcopy(old)
    for key, value in new.items():
        if key == "PostToolUse" and isinstance(result.get(key), list) and isinstance(value, list):
            result[key] = merge_post_tool_use(result[key], value)
            continue
        result[key] = overlay(result[key], value) if key in result else copy.deepcopy(value)
    return result

effective = overlay(existing, managed)

bare_key = re.compile(r"^[A-Za-z0-9_-]+$")

def key_text(key):
    return key if bare_key.fullmatch(str(key)) else json.dumps(str(key), ensure_ascii=False)

def scalar(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, int) and not isinstance(value, bool):
        return str(value)
    if isinstance(value, float):
        if math.isnan(value):
            return "nan"
        if math.isinf(value):
            return "inf" if value > 0 else "-inf"
        return repr(value)
    if isinstance(value, (dt.datetime, dt.date, dt.time)):
        return value.isoformat()
    if isinstance(value, list):
        return "[" + ", ".join(scalar(item) for item in value) + "]"
    if isinstance(value, dict):
        pairs = []
        for key, item in value.items():
            pairs.append(f"{key_text(key)} = {scalar(item)}")
        return "{ " + ", ".join(pairs) + " }"
    raise TypeError(f"unsupported TOML value {type(value).__name__}")

lines = []

def render_table(path, table):
    scalar_items = [(key, value) for key, value in table.items() if not isinstance(value, dict)]
    table_items = [(key, value) for key, value in table.items() if isinstance(value, dict)]
    if path:
        lines.append("[" + ".".join(key_text(part) for part in path) + "]")
    for key, value in scalar_items:
        lines.append(f"{key_text(key)} = {scalar(value)}")
    if path and (scalar_items or table_items):
        lines.append("")
    for index, (key, value) in enumerate(table_items):
        render_table(path + [key], value)
        if index != len(table_items) - 1:
            lines.append("")

root_scalars = [(key, value) for key, value in effective.items() if not isinstance(value, dict)]
root_tables = [(key, value) for key, value in effective.items() if isinstance(value, dict)]
for key, value in root_scalars:
    lines.append(f"{key_text(key)} = {scalar(value)}")
if root_scalars and root_tables:
    lines.append("")
for index, (key, value) in enumerate(root_tables):
    render_table([key], value)
    if index != len(root_tables) - 1:
        lines.append("")
rendered = "\n".join(lines).rstrip() + "\n"

try:
    rendered_data = tomllib.loads(rendered)
except tomllib.TOMLDecodeError as exc:
    raise SystemExit(f"generated config is invalid TOML: {exc}")
if rendered_data != effective:
    raise SystemExit("generated config did not round-trip to the intended TOML data")

current = None
mode = 0o600
if target.exists() and not target.is_symlink():
    current = target.read_text(encoding="utf-8")
    try:
        mode = stat.S_IMODE(target.stat().st_mode)
    except OSError:
        pass
elif target.is_symlink():
    try:
        current = target.read_text(encoding="utf-8")
        mode = stat.S_IMODE(target.stat().st_mode)
    except OSError:
        current = None

# A regular effective config is intentionally left alone when its data already
# matches. Even a template symlink is migrated to a regular file so a later
# run can preserve machine-local values independently of the repository.
if current is not None and not target.is_symlink() and existing == effective:
    print(f"unchanged {target}")
    raise SystemExit(0)

fd, temp_name = tempfile.mkstemp(prefix=f".{target.name}.", dir=str(target.parent), text=True)
backup = None
try:
    os.fchmod(fd, mode)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(rendered)
    with open(temp_name, "rb") as handle:
        if tomllib.load(handle) != effective:
            raise RuntimeError("validated temporary config differs from intended TOML data")

    if target.is_symlink() or target.exists():
        if target.is_dir() and not target.is_symlink():
            raise SystemExit(f"refusing to replace directory {target}")
        stamp = time.strftime("%Y%m%d%H%M%S")
        backup = target.with_name(target.name + f".codex-backup-{stamp}-{os.getpid()}")
        index = 0
        while backup.exists() or backup.is_symlink():
            index += 1
            backup = target.with_name(target.name + f".codex-backup-{stamp}-{os.getpid()}-{index}")
        os.replace(target, backup)
    os.replace(temp_name, target)
    if backup is not None:
        print(f"backed up {target} -> {backup}")
except Exception:
    try:
        os.unlink(temp_name)
    except FileNotFoundError:
        pass
    if backup is not None and not target.exists() and not target.is_symlink():
        os.replace(backup, target)
    raise
print(f"synced {target}")
PY
}

[ -f "$managed_config" ] || die "missing managed config: $managed_config"
[ -f "$repo_root/codex/AGENTS.md" ] || die "missing AGENTS file"
[ -x "$(command -v python3 2>/dev/null || true)" ] || die "python3 is required to merge Codex TOML safely"

for codex_home in "$default_codex_home" "$xdg_codex_home"; do
  mkdir -p "$codex_home" "$codex_home/agents"
  sync_config "$codex_home/config.toml"
  link_file "$repo_root/codex/AGENTS.md" "$codex_home/AGENTS.md"
  for profile in luna terra sol astra-readonly; do
    link_file "$repo_root/codex/$profile.config.toml" "$codex_home/$profile.config.toml"
  done
  for agent in luna terra sol; do
    link_file "$repo_root/codex/agents/$agent.toml" "$codex_home/agents/$agent.toml"
  done
  link_file "$repo_root/codex/hooks/comment-check.py" "$codex_home/hooks/comment-check.py"
done

for skill_dir in "$repo_root"/codex/skills/*; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  link_skill "$skill_dir" "$HOME/.agents/skills/$skill_name"
done

log "setup complete"
