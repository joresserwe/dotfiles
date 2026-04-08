#!/usr/bin/env bash
# install.linux.sh — WSL2/Ubuntu installer for the dotfiles repo.
# Counterpart to install.sh (macOS). Idempotent. Designed to be re-runnable.

set -euo pipefail

# ----- XDG defaults --------------------------------------------------------
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"

DOTFILES_PATH="$XDG_CONFIG_HOME/.dotfiles"

# ----- Library -------------------------------------------------------------
if [ ! -f "$DOTFILES_PATH/lib/common.sh" ]; then
  echo "ERROR: $DOTFILES_PATH/lib/common.sh not found. Clone the dotfiles repo first." >&2
  exit 1
fi
# shellcheck source=lib/common.sh
source "$DOTFILES_PATH/lib/common.sh"

# ============================================================================
# Phase 0 — Bootstrap (XDG dirs, apt packages, Homebrew on Linux)
# ============================================================================
log_step "Phase 0: Bootstrap"

ensure_dir \
  "$XDG_CACHE_HOME" \
  "$XDG_CONFIG_HOME" \
  "$XDG_DATA_HOME" \
  "$XDG_STATE_HOME" \
  "$XDG_STATE_HOME/zsh" \
  "$XDG_STATE_HOME/atuin/logs" \
  "$XDG_CONFIG_HOME/npm" \
  "$XDG_CONFIG_HOME/vim" \
  "$XDG_STATE_HOME/vim"

log_step "apt: install base packages from apt/packages.txt"
sudo apt-get update -y
# shellcheck disable=SC2046
sudo apt-get install -y $(grep -vE '^\s*#|^\s*$' "$DOTFILES_PATH/apt/packages.txt")

if ! command -v brew >/dev/null 2>&1 && [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  log_step "Installing Homebrew on Linux"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  log_skip "Homebrew already installed"
fi
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
brew analytics off

log_done "Phase 0 complete"

# ============================================================================
# Phase 1 — Shell (zsh + oh-my-zsh + powerlevel10k)
# ============================================================================
log_step "Phase 1: zsh, oh-my-zsh, powerlevel10k"

if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
  log_step "chsh to zsh"
  sudo chsh -s "$(command -v zsh)" "$USER"
else
  log_skip "default shell already zsh"
fi

create_link "$DOTFILES_PATH/zsh/.zshenv" "$HOME/.zshenv"
create_link "$DOTFILES_PATH/zsh/.zshrc"  "$XDG_CONFIG_HOME/zsh/.zshrc"
create_link "$DOTFILES_PATH/zsh/.aliases" "$XDG_CONFIG_HOME/zsh/.aliases"
[ -e "$XDG_CONFIG_HOME/zsh/zfunc" ] || ln -sf "$DOTFILES_PATH/zsh/zfunc" "$XDG_CONFIG_HOME/zsh/zfunc"

if [ ! -d "$XDG_CONFIG_HOME/zsh/oh-my-zsh" ]; then
  log_step "Installing oh-my-zsh"
  ZSH="$XDG_CONFIG_HOME/zsh/oh-my-zsh" RUNZSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  log_skip "oh-my-zsh already installed"
fi

P10K_DIR="$XDG_CONFIG_HOME/zsh/oh-my-zsh/custom/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  git clone --depth=1 https://github.com/joresserwe/powerlevel10k.git "$P10K_DIR"
else
  log_skip "powerlevel10k already cloned"
fi
create_link "$DOTFILES_PATH/zsh/.p10k.zsh" "$XDG_CONFIG_HOME/zsh/.p10k.zsh"

ZSH_AUTOSUG_DIR="$XDG_CONFIG_HOME/zsh/oh-my-zsh/custom/plugins/zsh-autosuggestions"
if [ ! -d "$ZSH_AUTOSUG_DIR" ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUG_DIR"
else
  log_skip "zsh-autosuggestions already cloned"
fi

log_done "Phase 1 complete"

# ============================================================================
# Phase 2 — Core CLI (brew bundle + tool configs)
# ============================================================================
log_step "Phase 2: brew bundle (Linux subset) + tool configs"

brew bundle install --file "$DOTFILES_PATH/brew/Brewfile"

create_link "$DOTFILES_PATH/git/config" "$XDG_CONFIG_HOME/git/config"
create_link "$DOTFILES_PATH/npm/npmrc"  "$XDG_CONFIG_HOME/npm/npmrc"

create_link "$DOTFILES_PATH/tmux/tmux.conf"         "$XDG_CONFIG_HOME/tmux/tmux.conf"
create_link "$DOTFILES_PATH/tmux/tmux.mapping.conf" "$XDG_CONFIG_HOME/tmux/tmux.mapping.conf"
create_link "$DOTFILES_PATH/tmux/gitmux.conf"       "$XDG_CONFIG_HOME/tmux/gitmux.conf"
create_link "$DOTFILES_PATH/tmux/smart-split.sh"    "$XDG_CONFIG_HOME/tmux/smart-split.sh"

create_link "$DOTFILES_PATH/atuin/config.toml" "$XDG_CONFIG_HOME/atuin/config.toml"

create_link "$DOTFILES_PATH/yazi/yazi.toml"   "$XDG_CONFIG_HOME/yazi/yazi.toml"
create_link "$DOTFILES_PATH/yazi/theme.toml"  "$XDG_CONFIG_HOME/yazi/theme.toml"
create_link "$DOTFILES_PATH/yazi/keymap.toml" "$XDG_CONFIG_HOME/yazi/keymap.toml"
create_link "$DOTFILES_PATH/yazi/init.lua"    "$XDG_CONFIG_HOME/yazi/init.lua"

# win32yank (WSL-only): clipboard tool for WSL. Preferred over clip.exe
# because it handles CRLF correctly and supports paste. Installed into
# ~/.local/bin (already on PATH via .zshenv). Pinned version for reproducibility.
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  WIN32YANK_BIN="$HOME/.local/bin/win32yank.exe"
  WIN32YANK_VERSION="v0.1.1"
  if [ ! -x "$WIN32YANK_BIN" ]; then
    log_step "Installing win32yank ${WIN32YANK_VERSION}"
    ensure_dir "$HOME/.local/bin"
    tmp_zip="$(mktemp --suffix=.zip)"
    curl -fsSL -o "$tmp_zip" \
      "https://github.com/equalsraf/win32yank/releases/download/${WIN32YANK_VERSION}/win32yank-x64.zip"
    unzip -p "$tmp_zip" win32yank.exe > "$WIN32YANK_BIN"
    chmod +x "$WIN32YANK_BIN"
    rm -f "$tmp_zip"
    log_done "win32yank installed: $WIN32YANK_BIN"
  else
    log_skip "win32yank already installed"
  fi
else
  log_skip "win32yank: not running under WSL"
fi

# WezTerm (Windows side): write a stub at %USERPROFILE%\.wezterm.lua that
# dofile()s the real config over the \\wsl.localhost UNC path. The real config
# self-registers in WezTerm's reload watch list so auto-reload works.
if [[ -n "${WSL_DISTRO_NAME:-}" ]] && command -v cmd.exe >/dev/null 2>&1; then
  win_userprofile_raw="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
  if [[ -n "$win_userprofile_raw" ]]; then
    win_userprofile_wsl="$(wslpath "$win_userprofile_raw")"
    stub_path="$win_userprofile_wsl/.wezterm.lua"
    unc_path="\\\\wsl.localhost\\${WSL_DISTRO_NAME}${DOTFILES_PATH//\//\\}\\wezterm\\wezterm.lua"
    cat > "$stub_path" <<EOF
-- Auto-generated by install.linux.sh — do not edit by hand.
-- Delegates to the real wezterm config inside WSL (${WSL_DISTRO_NAME}).
-- Register the real file in WezTerm's reload watch list directly here, since
-- the Lua sandbox doesn't expose 'debug' and globals don't persist across reloads.
local wezterm = require 'wezterm'
local real_config = [[${unc_path}]]
wezterm.add_to_config_reload_watch_list(real_config)
return dofile(real_config)
EOF
    log_done "wezterm stub written: $stub_path -> $unc_path"

    # Kick off the inotify→stub bridge so config auto-reload works immediately.
    # (.zshrc also (re)starts it on every new shell, idempotently.)
    if command -v inotifywait >/dev/null 2>&1; then
      nohup "$DOTFILES_PATH/wezterm/wezterm-watch.sh" >/dev/null 2>&1 &
      disown || true
      log_done "wezterm-watch started in background"
    else
      log_skip "wezterm-watch: inotify-tools not installed yet"
    fi
  else
    log_skip "wezterm stub: could not resolve %USERPROFILE%"
  fi
else
  log_skip "wezterm stub: not running under WSL or cmd.exe unavailable"
fi

if command -v ya >/dev/null 2>&1; then
  for pkg in \
    boydaihungst/mediainfo \
    ndtoan96/ouch \
    yazi-rs/plugins:jump-to-char \
    KKV9/archive \
    yazi-rs/plugins:full-border \
    yazi-rs/plugins:git \
    yazi-rs/plugins:smart-filter \
    yazi-rs/plugins:chmod \
    yazi-rs/plugins:toggle-pane \
    Reledia/glow \
    yazi-rs/flavors:catppuccin-mocha; do
    ya pkg add "$pkg" || log_skip "ya pkg add $pkg (already installed or failed)"
  done
else
  log_skip "ya command not found; skip yazi plugin install"
fi

log_done "Phase 2 complete"

# ============================================================================
# Phase 3 — Runtime (mise + node + global pnpm packages)
# ============================================================================
log_step "Phase 3: mise + node + global packages"

eval "$(mise activate bash)"
mise use -g node@lts
# mise activate hooks fire on prompt; in non-interactive bash we must add shims to PATH manually
export PATH="$XDG_DATA_HOME/mise/shims:$PATH"

export PNPM_HOME="${PNPM_HOME:-$XDG_DATA_HOME/pnpm}"
export PATH="$PNPM_HOME:$PATH"

for pkg in yarn npm-check-updates mcp-hub; do
  if pnpm list -g --depth=0 2>/dev/null | grep -q "$pkg"; then
    log_skip "pnpm global: $pkg"
  else
    pnpm install -g "$pkg"
    log_done "pnpm global: $pkg"
  fi
done

log_done "Phase 3 complete"

# ============================================================================
# Phase 4 — Editor (astronvim_config)
# ============================================================================
log_step "Phase 4: astronvim"

NVIM_DIR="$XDG_CONFIG_HOME/nvim"
ASTRONVIM_REPO="https://github.com/joresserwe/astronvim_config"

if [ -d "$NVIM_DIR/.git" ]; then
  REMOTE="$(git -C "$NVIM_DIR" config --get remote.origin.url 2>/dev/null || echo)"
  if [ "$REMOTE" = "$ASTRONVIM_REPO" ] || [ "$REMOTE" = "${ASTRONVIM_REPO}.git" ]; then
    log_skip "astronvim already cloned"
  else
    log_step "Backing up existing nvim dir to nvim_backup_$(date +%s)"
    mv "$NVIM_DIR" "${NVIM_DIR}_backup_$(date +%s)"
    git clone "$ASTRONVIM_REPO" "$NVIM_DIR"
  fi
elif [ -d "$NVIM_DIR" ]; then
  log_step "Backing up existing non-git nvim dir to nvim_backup_$(date +%s)"
  mv "$NVIM_DIR" "${NVIM_DIR}_backup_$(date +%s)"
  git clone "$ASTRONVIM_REPO" "$NVIM_DIR"
else
  git clone "$ASTRONVIM_REPO" "$NVIM_DIR"
fi

log_done "Phase 4 complete (run 'nvim --headless \"+Lazy! sync\" +qa' to pre-install plugins)"

# ============================================================================
# Phase 5 — Claude Code
# ============================================================================
log_step "Phase 5: Claude Code symlinks"

ensure_dir "$XDG_DATA_HOME/claude"

create_link "$DOTFILES_PATH/claude/settings.json" "$XDG_DATA_HOME/claude/settings.json"

if [ -L "$XDG_DATA_HOME/claude/skills" ] || [ ! -e "$XDG_DATA_HOME/claude/skills" ]; then
  ln -sfn "$DOTFILES_PATH/claude/skills" "$XDG_DATA_HOME/claude/skills"
  log_done "link: $XDG_DATA_HOME/claude/skills -> $DOTFILES_PATH/claude/skills"
else
  log_skip "$XDG_DATA_HOME/claude/skills exists and is not a symlink — leaving alone"
fi

if [ -L "$HOME/.claude" ] || [ ! -e "$HOME/.claude" ]; then
  ln -sfn "$XDG_DATA_HOME/claude" "$HOME/.claude"
  log_done "link: $HOME/.claude -> $XDG_DATA_HOME/claude"
else
  log_skip "$HOME/.claude exists and is not a symlink — leaving alone"
fi

log_done "Phase 5 complete"

# ============================================================================
log_step "All phases complete. Open a new shell (or 'exec zsh') to start using it."
