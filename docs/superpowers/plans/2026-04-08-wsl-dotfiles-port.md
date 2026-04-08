# WSL Dotfiles Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a WSL2/Ubuntu installer (`install.linux.sh`) to the existing macOS dotfiles repo so a fresh WSL install reaches a Mac-equivalent CLI dev environment, while preserving the macOS `install.sh` behavior with zero regression.

**Architecture:** Single repo, hybrid package strategy (apt + Homebrew on Linux), shared sourced library `lib/common.sh`, OS differences expressed as inline runtime branches inside shared config files (`case $OSTYPE` for shell, `if OS.mac?` for Brewfile). Each tool stays in one folder; no `darwin/`/`linux/` split folders. Mac-only tools (aerospace/karabiner/yabai/raycast/wallpaperkiller) are simply not touched by the Linux installer.

**Tech Stack:** bash/zsh, apt, Homebrew on Linux, oh-my-zsh, powerlevel10k, mise, neovim (astronvim), tmux, yazi, atuin, claude-code.

**No git commits.** Per user instruction, do not run `git add` / `git commit` during execution. Leave changes in the working tree.

**Verification model.** This plan touches shell scripts and config files, not application code. Each task ends with a **Verify** step that runs the relevant slice of `install.linux.sh` (or sources the modified config) and checks the resulting filesystem/shell state. Re-run each Verify a second time to confirm idempotency.

---

## File Structure

**New files:**
- `lib/common.sh` — sourced-only library (mode 644). Functions: `detect_os`, `create_link`, `ensure_dir`, `log_step`, `log_skip`, `log_done`. No top-level code.
- `install.linux.sh` — WSL/Ubuntu entrypoint. Sources `lib/common.sh`, runs phases 0–5 in order.
- `apt/packages.txt` — newline-separated apt package list.
- `docs/superpowers/specs/2026-04-08-wsl-dotfiles-port-design.md` — already created.

**Modified files (additive only inside OS guards):**
- `install.sh` — refactor to source `lib/common.sh`, replace inline `create_link` with library call. No behavioral change.
- `zsh/.zshenv` — add `case $OSTYPE` for `XDG_RUNTIME_DIR` and `HOMEBREW_PREFIX`; replace hardcoded `/opt/homebrew` eval.
- `zsh/.zshrc` — guard wezterm-specific paths; otherwise unchanged (most lines are portable).
- `zsh/.aliases` — gate `pbcopy`, `preview`, `gdu-go`, `wezterm`-using `fh` under darwin; provide linux equivalents.
- `brew/Brewfile` — wrap all `cask`, `mas`, and macOS-only formulae (`borders`, `watchman`, `mas`) inside `if OS.mac?`. Common formulae stay top-level.

**Untouched (Mac-only, ignored by Linux installer):** `aerospace/`, `karabiner/`, `yabai/`, `raycast/`, `wallpaperkiller/`, all `defaults write` blocks, all `open -a` blocks.

---

## Task 1: Create `lib/common.sh` (sourced library)

**Files:**
- Create: `lib/common.sh`

- [ ] **Step 1: Create the library file**

Write `/home/cyan/.config/.dotfiles/lib/common.sh` with this exact content:

```sh
# lib/common.sh — shared functions for install.sh (macOS) and install.linux.sh (WSL/Ubuntu).
# This file is SOURCED, never executed. No top-level side effects. Mode 644.

# Refuse direct execution.
if [ "${BASH_SOURCE[0]:-${(%):-%x}}" = "${0}" ]; then
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

log_step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
log_skip() { printf '    \033[2;37m-- %s\033[0m\n' "$*"; }
log_done() { printf '    \033[1;32mok\033[0m %s\n' "$*"; }

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
```

- [ ] **Step 2: Ensure mode 644 (no execute bit)**

Run: `chmod 644 /home/cyan/.config/.dotfiles/lib/common.sh`
Verify: `ls -l /home/cyan/.config/.dotfiles/lib/common.sh` shows `-rw-r--r--`.

- [ ] **Step 3: Smoke-test the library**

Run:
```bash
bash -c 'source /home/cyan/.config/.dotfiles/lib/common.sh && detect_os && ensure_dir /tmp/dotfiles-test && create_link /etc/hostname /tmp/dotfiles-test/hostname-link && ls -l /tmp/dotfiles-test'
```
Expected: prints `linux`, creates `/tmp/dotfiles-test`, symlinks `hostname-link → /etc/hostname`. Cleanup: `rm -rf /tmp/dotfiles-test`.

- [ ] **Step 4: Verify direct-execution guard**

Run: `bash /home/cyan/.config/.dotfiles/lib/common.sh; echo "exit=$?"`
Expected: prints `lib/common.sh is a library; source it instead of executing.` and `exit=1`.

---

## Task 2: Refactor `install.sh` (macOS) to use `lib/common.sh`

**Goal:** Mac behavior unchanged; only the `create_link` definition is moved into the library. This task contains zero functional changes.

**Files:**
- Modify: `install.sh:160-170` (the `create_link` function definition)
- Modify: `install.sh:1-11` (header — add source line)

- [ ] **Step 1: Add `source` line near the top of `install.sh`**

After line 10 (`DOTFILES_PATH="$XDG_CONFIG_HOME/.dotfiles"`), insert a blank line and:
```sh
source "$DOTFILES_PATH/lib/common.sh"
```

- [ ] **Step 2: Delete the inline `create_link` function from `install.sh`**

Remove lines 161–170 (the entire `create_link() { ... }` block) since the library now provides it. Leave the surrounding `echo "설정파일 Symbolic Lync 연결..."` line and the `# zsh` comment intact.

- [ ] **Step 3: Verify the file still parses (zsh syntax check)**

Run: `zsh -n /home/cyan/.config/.dotfiles/install.sh && echo OK`
Expected: prints `OK`. (Note: this only checks syntax; we cannot run the full installer on WSL. The user will smoke-test on macOS separately.)

- [ ] **Step 4: Manual Mac regression checklist (user runs on Mac)**

Document in the plan execution log: user must, on their Mac, run `zsh -n install.sh`, then optionally re-run `install.sh` and confirm no errors and no unexpected diff in linked files.

---

## Task 3: Add OS branching to `zsh/.zshenv`

**Files:**
- Modify: `zsh/.zshenv:6` (commented `XDG_RUNTIME_DIR`)
- Modify: `zsh/.zshenv:15-16` (hardcoded brew shellenv)

- [ ] **Step 1: Replace the `XDG_RUNTIME_DIR` line and brew shellenv block**

In `zsh/.zshenv`, replace lines 6 and 15–16 so that the file reads:

```sh
# XDG(https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# OS-specific: XDG_RUNTIME_DIR and Homebrew prefix
case "$OSTYPE" in
  darwin*)
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$HOME/Library/Caches/Runtime}"
    export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"
    [ -x "$HOMEBREW_PREFIX/bin/brew" ] || export HOMEBREW_PREFIX="/usr/local"
    ;;
  linux*)
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
    export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
    ;;
esac
[ -x "$HOMEBREW_PREFIX/bin/brew" ] && eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
```

Keep all other lines (zsh, MYVIMRC, mise, npm, sdkman, go, wget, fzf, nvim, pipx, claude code, less, vscode) unchanged.

- [ ] **Step 2: Syntax check**

Run: `zsh -n /home/cyan/.config/.dotfiles/zsh/.zshenv && echo OK`
Expected: `OK`.

- [ ] **Step 3: Verify Mac semantics preserved (visual diff)**

Run: `git -C /home/cyan/.config/.dotfiles diff zsh/.zshenv`
Expected: the darwin branch sets the same `XDG_RUNTIME_DIR` and HOMEBREW_PREFIX values that the original file used. No darwin-relevant export was deleted.

---

## Task 4: Guard macOS-only sections in `zsh/.zshrc`

**Files:**
- Modify: `zsh/.zshrc:24` (`zsh-vi-mode` path uses HOMEBREW_PREFIX — already portable, no change)
- Modify: `zsh/.zshrc:22` (`zsh-syntax-highlighting` — also portable via HOMEBREW_PREFIX, no change)

After review, `.zshrc` is already portable: every Homebrew path is via `$HOMEBREW_PREFIX`, and oh-my-zsh/p10k/mise/atuin/zoxide/carapace all work on Linux. **No edits required for this task.**

- [ ] **Step 1: Confirm no edits needed**

Run: `grep -n -E '/opt/homebrew|/usr/local|darwin|Darwin|/Library/' /home/cyan/.config/.dotfiles/zsh/.zshrc || echo "no mac-specific paths"`
Expected: prints `no mac-specific paths`.

- [ ] **Step 2: Mark task complete with no changes**

Note in execution log: `.zshrc` is already OS-agnostic; task is a no-op confirmation.

---

## Task 5: Add OS branching to `zsh/.aliases`

**Files:**
- Modify: `zsh/.aliases:9` (`preview` uses `open -a`)
- Modify: `zsh/.aliases:56,83,109,140` (`pbcopy` in fzf bind functions `ff`, `f/`, `fz`, `fa`)
- Modify: `zsh/.aliases:117-125` (`fh` uses `wezterm cli`)
- Modify: `zsh/.aliases:165` (`disk` aliases to `gdu-go`)

- [ ] **Step 1: Add a portable `_dotfiles_copy` helper near the top of `.aliases`**

Insert after line 1 (`# zsh`):
```sh
# OS-portable clipboard copy (used by fzf bind functions below)
case "$OSTYPE" in
  darwin*) _dotfiles_copy() { pbcopy; } ;;
  linux*)
    if command -v wl-copy >/dev/null 2>&1; then
      _dotfiles_copy() { wl-copy; }
    elif command -v xclip >/dev/null 2>&1; then
      _dotfiles_copy() { xclip -selection clipboard; }
    elif command -v clip.exe >/dev/null 2>&1; then
      # WSL fallback: pipe to Windows clipboard
      _dotfiles_copy() { clip.exe; }
    else
      _dotfiles_copy() { cat >/dev/null; }
    fi
    ;;
esac
```

- [ ] **Step 2: Replace `pbcopy` calls with `_dotfiles_copy`**

In each of the 4 fzf bind strings, replace `pbcopy` with `_dotfiles_copy`:
- `ff` (line ~56): `--bind "ctrl-y:execute-silent(echo -n {} | _dotfiles_copy)+abort"`
- `f/` (line ~83): `--bind "ctrl-y:execute-silent(echo -n {1} | _dotfiles_copy)+abort"`
- `fz` (line ~109): `--bind "ctrl-y:execute-silent(echo -n {2..} | _dotfiles_copy)+abort"`
- `fa` (line ~140): `--bind "ctrl-y:execute-silent(echo -n {} | _dotfiles_copy)+abort"`

- [ ] **Step 3: Gate the `preview` alias under darwin**

Replace lines 8–9 with:
```sh
# Preview (macOS Preview.app)
case "$OSTYPE" in
  darwin*) alias preview="open -a Preview" ;;
esac
```

- [ ] **Step 4: Gate the `disk` alias by binary name**

Replace line 165 with:
```sh
# gdu — binary name differs by platform
if command -v gdu-go >/dev/null 2>&1; then
  alias disk="gdu-go"
elif command -v gdu >/dev/null 2>&1; then
  alias disk="gdu"
fi
```

- [ ] **Step 5: Gate the wezterm-using `fh` function under darwin (WSL uses plain atuin)**

Replace the `fh()` function (lines ~117–125) with:
```sh
# fh: fuzzy history (atuin). On macOS+wezterm, opens a side pane with stats.
fh() {
  case "$OSTYPE" in
    darwin*)
      if [ -n "$WEZTERM_PANE" ] && command -v wezterm >/dev/null 2>&1; then
        local stats_pane current_pane
        current_pane="$WEZTERM_PANE"
        stats_pane=$(wezterm cli split-pane --right --percent 30 -- bash -c 'atuin stats; printf "\e[?25l"; cat > /dev/null')
        wezterm cli activate-pane --pane-id "$current_pane" 2>/dev/null
        wezterm cli activate-pane --pane-id "$current_pane" 2>/dev/null
        atuin search -i "$@"
        wezterm cli kill-pane --pane-id "$stats_pane" 2>/dev/null
        return
      fi
      ;;
  esac
  atuin search -i "$@"
}
```

- [ ] **Step 6: Syntax check**

Run: `zsh -n /home/cyan/.config/.dotfiles/zsh/.aliases && echo OK`
Expected: `OK`.

---

## Task 6: Wrap macOS-only entries in `brew/Brewfile`

**Files:**
- Modify: `brew/Brewfile` — wrap casks, mas, and Linux-incompatible formulae in `if OS.mac?` blocks.

- [ ] **Step 1: Identify Linux-incompatible entries**

These must move inside `if OS.mac?`:
- All `cask "..."` lines (Linux brew has no cask support)
- All `mas "..."` lines (Mac App Store)
- `brew "mas"` (Mac App Store CLI)
- `brew "watchman"` (Linux build is fragile and not needed for our use)
- `brew "felixkratz/formulae/borders"` (macOS UI tool)
- `tap "felixkratz/formulae"` (only used by borders)

All other formulae are Linux-compatible and stay top-level.

- [ ] **Step 2: Rewrite Brewfile**

Rewrite `/home/cyan/.config/.dotfiles/brew/Brewfile` to this structure (preserving every existing comment for Linux-compatible formulae):

```ruby
tap "arl/arl"

# ====== Cross-platform CLI ======
# 쉘 히스토리를 SQLite에 저장하고 동기화하는 도구
brew "atuin"
# Clone of cat(1) with syntax highlighting and Git integration
brew "bat"
# Yet another cross-platform graphical process/system monitor
brew "bottom"
# Fix common misspellings in source code and text files
brew "codespell"
# Maintained ctags implementation
brew "universal-ctags"
# Get a file from an HTTP, HTTPS or FTP server
brew "curl"
# Syntax-highlighting pager for git and diff output
brew "git-delta"
# Modern, maintained replacement for ls
brew "eza"
# Simple, fast and user-friendly alternative to find
brew "fd"
# Command-line fuzzy finder written in Go
brew "fzf"
# Disk usage analyzer with console interface written in Go
brew "gdu"
# Distributed revision control system
brew "git"
# Render markdown on the CLI
brew "glow"
# GNU implementation of the famous stream editor
brew "gnu-sed"
# Open source programming language to build simple/reliable/efficient software
brew "go"
# User-friendly cURL replacement (command-line HTTP client)
brew "httpie"
# Lightweight and flexible command-line JSON processor
brew "jq"
# Kubernetes command-line interface
brew "kubernetes-cli"
# Simple terminal UI for git commands
brew "lazygit"
# Tool for linting and static analysis of Lua code
brew "luacheck"
# Package manager for the Lua programming language
brew "luarocks"
# Ambitious Vim-fork focused on extensibility and agility
brew "neovim"
# Polyglot runtime/version manager (replaces fnm + pyenv)
brew "mise"
# Renders an animated, color, ANSI-text loop of the Poptart Cat
brew "nyancat"
# Fast, disk space efficient package manager
brew "pnpm"
# Python package installer and resolver
brew "uv"
# Search tool like grep and The Silver Searcher
brew "ripgrep"
# Ping with a real-time graph
brew "gping"
# TCP connect to the given IP/port combo
brew "tcping"
# User interface to the TELNET protocol
brew "telnet"
# Display directories as trees (with optional color/HTML output)
brew "tree"
# Executes a program periodically, showing output fullscreen
brew "watch"
# Blazing fast terminal file manager written in Rust, based on async I/O
brew "yazi"
# Shell extension to navigate your filesystem faster
brew "zoxide"
# Fish shell like syntax highlighting for zsh
brew "zsh-syntax-highlighting"
# Vim keybindings for zsh line editor
brew "zsh-vi-mode"
# Multi-shell unified completion engine for 600+ CLIs
brew "carapace"
# Git in your tmux status bar.
brew "arl/arl/gitmux"

# ====== macOS only ======
if OS.mac?
  tap "felixkratz/formulae"
  # Mac App Store command-line interface
  brew "mas"
  # Watch files and take action when they change
  brew "watchman"
  # A window border system for macOS
  brew "felixkratz/formulae/borders"
  # [DEPRECATED] yabai/skhd → replaced by aerospace
  # brew "koekeishiya/formulae/skhd"
  # brew "koekeishiya/formulae/yabai"

  # GPU-accelerated cross-platform terminal emulator
  cask "wezterm"
  # AeroSpace is an i3-like tiling window manager for macOS
  cask "aerospace"
  # Enable Windows-like alt-tab
  cask "alt-tab"
  # Tool to remove unnecessary files and folders from disk
  cask "cleanmymac"
  # Developer targeted fonts with a high number of glyphs
  cask "font-hack-nerd-font"
  # Nerd Font patched version of 0xProto
  cask "font-0xproto-nerd-font"
  # Sans-serif variant of "San Francisco" by Apple
  cask "font-sf-pro"
  # Web browser
  cask "google-chrome"
  # JetBrains tools manager
  cask "jetbrains-toolbox"
  # Keyboard customiser
  cask "karabiner-elements"
  # Media player
  cask "movist-pro"
  # App to write, plan, collaborate, and get organised
  cask "notion"
  # Control your tools with a few keystrokes
  cask "raycast"
  # Tool to reverse the direction of scrolling
  cask "scroll-reverser"
  # Tool that provides consistent, highly configurable symbols for apps
  cask "sf-symbols"
  cask "keyclu"

  mas "Hidden Bar", id: 1452453066
  mas "Microsoft PowerPoint", id: 462062816
  mas "OneDrive", id: 823766827
  mas "QuickFTP", id: 1451646819
  mas "RunCat", id: 1429033973
  mas "Vimari", id: 1480933944
end
```

- [ ] **Step 3: Validate Brewfile syntax (Linux brew not yet installed; defer)**

Run: `grep -c '^if OS.mac?$' /home/cyan/.config/.dotfiles/brew/Brewfile` → expect `1`.
Run: `grep -c '^end$' /home/cyan/.config/.dotfiles/brew/Brewfile` → expect `1`.
Full validation happens in Task 9 once brew is installed.

---

## Task 7: Create `apt/packages.txt`

**Files:**
- Create: `apt/packages.txt`

- [ ] **Step 1: Write the apt package list**

Write `/home/cyan/.config/.dotfiles/apt/packages.txt`:

```text
build-essential
ca-certificates
curl
file
git
procps
unzip
zsh
```

Rationale: this is the *minimum* needed to install Homebrew on Linux and clone the dotfiles repo. Everything else (eza, bat, fd, ripgrep, neovim, etc.) comes via brew so versions match macOS.

---

## Task 8: Create `install.linux.sh` Phase 0 (Bootstrap)

**Files:**
- Create: `install.linux.sh`

- [ ] **Step 1: Create the file with shebang and Phase 0**

Write `/home/cyan/.config/.dotfiles/install.linux.sh`:

```bash
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
# Phase 0 — Bootstrap
# ============================================================================
log_step "Phase 0: Bootstrap (XDG dirs, apt packages, Homebrew on Linux)"

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

# apt packages
log_step "apt: install base packages from apt/packages.txt"
sudo apt-get update -y
# shellcheck disable=SC2046
sudo apt-get install -y $(grep -vE '^\s*#|^\s*$' "$DOTFILES_PATH/apt/packages.txt")

# Homebrew on Linux
if ! command -v brew >/dev/null 2>&1 && [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  log_step "Installing Homebrew on Linux"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  log_skip "Homebrew already installed"
fi
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
brew analytics off

log_done "Phase 0 complete"
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x /home/cyan/.config/.dotfiles/install.linux.sh`
Verify: `ls -l /home/cyan/.config/.dotfiles/install.linux.sh` → mode `-rwxr-xr-x`.

- [ ] **Step 3: Syntax check**

Run: `bash -n /home/cyan/.config/.dotfiles/install.linux.sh && echo OK`
Expected: `OK`.

- [ ] **Step 4: Run Phase 0**

Run: `/home/cyan/.config/.dotfiles/install.linux.sh`
Expected:
- All XDG dirs printed as either `created:` or `exists:`
- apt installs (or reports already installed) the 8 packages
- Homebrew installs at `/home/linuxbrew/.linuxbrew` (or skipped)
- Final log: `ok Phase 0 complete`

- [ ] **Step 5: Idempotency check**

Run: `/home/cyan/.config/.dotfiles/install.linux.sh` again.
Expected: every dir reports `exists:`, apt reports nothing to install, Homebrew reports already installed, no errors. Confirms re-runnability.

- [ ] **Step 6: Verify brew works**

Run: `/home/linuxbrew/.linuxbrew/bin/brew --version`
Expected: prints a version number.

---

## Task 9: Add Phase 1 (Shell — zsh) to `install.linux.sh`

**Files:**
- Modify: `install.linux.sh` — append Phase 1 block

- [ ] **Step 1: Append Phase 1 block**

Append to `install.linux.sh` after the `Phase 0 complete` log line:

```bash
# ============================================================================
# Phase 1 — Shell (zsh + oh-my-zsh + powerlevel10k)
# ============================================================================
log_step "Phase 1: zsh, oh-my-zsh, powerlevel10k"

# 1a. Make zsh the default login shell
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
  log_step "chsh to zsh"
  sudo chsh -s "$(command -v zsh)" "$USER"
else
  log_skip "default shell already zsh"
fi

# 1b. Symlink zsh dotfiles
create_link "$DOTFILES_PATH/zsh/.zshenv" "$HOME/.zshenv"
create_link "$DOTFILES_PATH/zsh/.zshrc"  "$XDG_CONFIG_HOME/zsh/.zshrc"
create_link "$DOTFILES_PATH/zsh/.aliases" "$XDG_CONFIG_HOME/zsh/.aliases"
[ -e "$XDG_CONFIG_HOME/zsh/zfunc" ] || ln -sf "$DOTFILES_PATH/zsh/zfunc" "$XDG_CONFIG_HOME/zsh/zfunc"

# 1c. oh-my-zsh
if [ ! -d "$XDG_CONFIG_HOME/zsh/oh-my-zsh" ]; then
  log_step "Installing oh-my-zsh"
  ZSH="$XDG_CONFIG_HOME/zsh/oh-my-zsh" RUNZSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  log_skip "oh-my-zsh already installed"
fi

# 1d. powerlevel10k theme
P10K_DIR="$XDG_CONFIG_HOME/zsh/oh-my-zsh/custom/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  git clone --depth=1 https://github.com/joresserwe/powerlevel10k.git "$P10K_DIR"
else
  log_skip "powerlevel10k already cloned"
fi
create_link "$DOTFILES_PATH/zsh/.p10k.zsh" "$XDG_CONFIG_HOME/zsh/.p10k.zsh"

# 1e. zsh-autosuggestions plugin
ZSH_AUTOSUG_DIR="$XDG_CONFIG_HOME/zsh/oh-my-zsh/custom/plugins/zsh-autosuggestions"
if [ ! -d "$ZSH_AUTOSUG_DIR" ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUG_DIR"
else
  log_skip "zsh-autosuggestions already cloned"
fi

log_done "Phase 1 complete"
```

- [ ] **Step 2: Run Phase 1**

Run: `/home/cyan/.config/.dotfiles/install.linux.sh`
Expected: Phase 0 reports all skips; Phase 1 creates symlinks, installs oh-my-zsh, clones p10k and zsh-autosuggestions. Ends with `ok Phase 1 complete`.

- [ ] **Step 3: Verify symlinks**

Run:
```bash
ls -l ~/.zshenv \
      ~/.config/zsh/.zshrc \
      ~/.config/zsh/.aliases \
      ~/.config/zsh/zfunc \
      ~/.config/zsh/.p10k.zsh
```
Expected: all five are symlinks pointing into `~/.config/.dotfiles/zsh/...`.

- [ ] **Step 4: Source the shell and confirm no errors**

Run: `zsh -i -c 'echo SHELL_OK; alias ll; type detect_os 2>/dev/null || true'`
Expected: prints `SHELL_OK` and the `ll` alias definition. No "command not found" or syntax errors. (Some tools — eza, atuin, mise — are not installed yet, so warnings about those are acceptable; hard syntax errors are not.)

- [ ] **Step 5: Idempotency check**

Re-run `install.linux.sh`. Expect every Phase 1 step to skip.

---

## Task 10: Add Phase 2 (Core CLI via brew) to `install.linux.sh`

**Files:**
- Modify: `install.linux.sh` — append Phase 2 block

- [ ] **Step 1: Append Phase 2 block**

```bash
# ============================================================================
# Phase 2 — Core CLI (brew bundle + tool configs)
# ============================================================================
log_step "Phase 2: brew bundle (Linux subset) + tool configs"

brew bundle install --file "$DOTFILES_PATH/brew/Brewfile"

# git
create_link "$DOTFILES_PATH/git/config" "$XDG_CONFIG_HOME/git/config"

# npm
create_link "$DOTFILES_PATH/npm/npmrc" "$XDG_CONFIG_HOME/npm/npmrc"

# tmux
create_link "$DOTFILES_PATH/tmux/tmux.conf"         "$XDG_CONFIG_HOME/tmux/tmux.conf"
create_link "$DOTFILES_PATH/tmux/tmux.mapping.conf" "$XDG_CONFIG_HOME/tmux/tmux.mapping.conf"
create_link "$DOTFILES_PATH/tmux/gitmux.conf"       "$XDG_CONFIG_HOME/tmux/gitmux.conf"
create_link "$DOTFILES_PATH/tmux/smart-split.sh"    "$XDG_CONFIG_HOME/tmux/smart-split.sh"

# atuin
create_link "$DOTFILES_PATH/atuin/config.toml" "$XDG_CONFIG_HOME/atuin/config.toml"

# yazi
create_link "$DOTFILES_PATH/yazi/yazi.toml"   "$XDG_CONFIG_HOME/yazi/yazi.toml"
create_link "$DOTFILES_PATH/yazi/theme.toml"  "$XDG_CONFIG_HOME/yazi/theme.toml"
create_link "$DOTFILES_PATH/yazi/keymap.toml" "$XDG_CONFIG_HOME/yazi/keymap.toml"
create_link "$DOTFILES_PATH/yazi/init.lua"    "$XDG_CONFIG_HOME/yazi/init.lua"

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
```

- [ ] **Step 2: Run Phase 2**

Run: `/home/cyan/.config/.dotfiles/install.linux.sh`
Expected: brew installs all Linux-compatible formulae from the Brewfile (Mac-only entries silently skipped by `if OS.mac?`). Symlinks created. Ends with `ok Phase 2 complete`.

- [ ] **Step 3: Verify core tools**

Run:
```bash
for cmd in eza bat fd rg fzf git delta gdu glow jq lazygit neovim mise pnpm yazi atuin zoxide tmux gitmux carapace tree httpie; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf 'OK   %s\n' "$cmd"
  else
    printf 'MISS %s\n' "$cmd"
  fi
done
```
Expected: every tool prints `OK`. (Note: `delta` is `git-delta`, `neovim` binary is `nvim` — adjust check if needed.)

- [ ] **Step 4: Verify config symlinks**

Run:
```bash
for f in ~/.config/git/config ~/.config/tmux/tmux.conf ~/.config/atuin/config.toml ~/.config/yazi/yazi.toml; do
  [ -L "$f" ] && echo "OK $f" || echo "MISS $f"
done
```
Expected: all four `OK`.

- [ ] **Step 5: Idempotency check**

Re-run `install.linux.sh`. brew bundle should report all already installed, every link should re-create cleanly without errors.

---

## Task 11: Add Phase 3 (Runtime — mise + node) to `install.linux.sh`

**Files:**
- Modify: `install.linux.sh` — append Phase 3 block

- [ ] **Step 1: Append Phase 3 block**

```bash
# ============================================================================
# Phase 3 — Runtime (mise + node + global pnpm packages)
# ============================================================================
log_step "Phase 3: mise + node + global packages"

eval "$(mise activate bash)"
mise use -g node@lts

# Ensure pnpm is on PATH for this session
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
```

- [ ] **Step 2: Run Phase 3**

Run: `/home/cyan/.config/.dotfiles/install.linux.sh`
Expected: mise installs node LTS, pnpm globals install. Ends with `ok Phase 3 complete`.

- [ ] **Step 3: Verify**

Run: `node --version && yarn --version && ncu --version`
Expected: three version strings.

- [ ] **Step 4: Idempotency check**

Re-run `install.linux.sh`. Phase 3 should report `mise use` as already-active and pnpm globals as skipped.

---

## Task 12: Add Phase 4 (Editor — astronvim) to `install.linux.sh`

**Files:**
- Modify: `install.linux.sh` — append Phase 4 block

- [ ] **Step 1: Append Phase 4 block**

```bash
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

log_done "Phase 4 complete (run nvim once to let Lazy sync plugins)"
```

- [ ] **Step 2: Run Phase 4**

Run: `/home/cyan/.config/.dotfiles/install.linux.sh`
Expected: clones astronvim_config to `~/.config/nvim`. Ends with `ok Phase 4 complete`.

- [ ] **Step 3: First-launch sync**

Run: `nvim --headless "+Lazy! sync" +qa`
Expected: Lazy plugin manager downloads all plugins. May take a minute. Exits cleanly.

- [ ] **Step 4: Verify**

Run: `ls ~/.config/nvim/init.lua && nvim --version | head -1`
Expected: file exists; nvim version printed.

- [ ] **Step 5: Idempotency check**

Re-run `install.linux.sh`. Expect `astronvim already cloned`.

---

## Task 13: Add Phase 5 (Claude Code) to `install.linux.sh`

**Files:**
- Modify: `install.linux.sh` — append Phase 5 block

**Note:** This user already has `~/.claude → /home/cyan/.local/share/claude` set up (verified during exploration). Phase 5 must be safe in that case.

- [ ] **Step 1: Append Phase 5 block**

```bash
# ============================================================================
# Phase 5 — Claude Code
# ============================================================================
log_step "Phase 5: Claude Code symlinks"

ensure_dir "$XDG_DATA_HOME/claude"

create_link "$DOTFILES_PATH/claude/settings.json" "$XDG_DATA_HOME/claude/settings.json"

# skills directory: link the whole dir
if [ -L "$XDG_DATA_HOME/claude/skills" ] || [ ! -e "$XDG_DATA_HOME/claude/skills" ]; then
  ln -sfn "$DOTFILES_PATH/claude/skills" "$XDG_DATA_HOME/claude/skills"
  log_done "link: $XDG_DATA_HOME/claude/skills -> $DOTFILES_PATH/claude/skills"
else
  log_skip "$XDG_DATA_HOME/claude/skills exists and is not a symlink — leaving alone"
fi

# ~/.claude → $XDG_DATA_HOME/claude (Claude Code does not fully respect XDG)
if [ -L "$HOME/.claude" ] || [ ! -e "$HOME/.claude" ]; then
  ln -sfn "$XDG_DATA_HOME/claude" "$HOME/.claude"
  log_done "link: $HOME/.claude -> $XDG_DATA_HOME/claude"
else
  log_skip "$HOME/.claude exists and is not a symlink — leaving alone"
fi

log_done "Phase 5 complete"
```

- [ ] **Step 2: Run Phase 5**

Run: `/home/cyan/.config/.dotfiles/install.linux.sh`
Expected: symlinks created or skipped. Ends with `ok Phase 5 complete`.

- [ ] **Step 3: Verify**

Run:
```bash
ls -l ~/.claude ~/.local/share/claude/settings.json ~/.local/share/claude/skills
```
Expected: `~/.claude` is a symlink to `~/.local/share/claude`; `settings.json` and `skills` resolve into the dotfiles repo.

---

## Task 14: Add Phase 6 (Documentation) — README section

**Files:**
- Modify: `README.md` — append "WSL2 / Ubuntu" section

- [ ] **Step 1: Append a WSL section to README**

Append to `/home/cyan/.config/.dotfiles/README.md`:

```markdown
## WSL2 / Ubuntu

For Windows users running WSL2 Ubuntu, use `install.linux.sh` instead of `install.sh`:

```bash
git clone https://github.com/joresserwe/dotfiles ~/.config/.dotfiles
~/.config/.dotfiles/install.linux.sh
```

The Linux installer reproduces the macOS CLI environment (zsh + oh-my-zsh + powerlevel10k, neovim/astronvim, tmux, yazi, atuin, mise, claude code) using a hybrid apt + Homebrew-on-Linux setup. macOS-only tools (aerospace, karabiner, raycast, …) are skipped automatically.

### Windows-side setup (manual)

These are not automated — set them up once on the Windows side:

1. **Nerd Font** — install `MesloLGS NF` (or any Nerd Font) and select it in Windows Terminal / wezterm-windows so powerlevel10k icons render.
2. **Default profile** — in Windows Terminal, set the default profile to launch `wsl.exe -d Ubuntu` so new tabs land in zsh.
3. **Clipboard** — clipboard integration works out of the box: tmux uses `set-clipboard on` (OSC 52) and the `_dotfiles_copy` shell helper falls back to `clip.exe` if no Wayland/X clipboard tool is present.

### Phase-by-phase

`install.linux.sh` runs phases 0–5 in order and is fully idempotent — re-running it after editing config files re-applies symlinks safely. To run a single phase manually, copy the relevant block from the script.
```

- [ ] **Step 2: Verify markdown renders**

Run: `head -60 /home/cyan/.config/.dotfiles/README.md && echo --- && tail -30 /home/cyan/.config/.dotfiles/README.md`
Expected: original content above the new section, new WSL section at the bottom.

---

## Task 15: Final end-to-end re-run + Mac smoke check

- [ ] **Step 1: Full clean re-run**

Run: `/home/cyan/.config/.dotfiles/install.linux.sh 2>&1 | tee /tmp/install.linux.log`
Expected: every phase reports skips or no-ops, no errors, exits 0.

- [ ] **Step 2: Search log for errors**

Run: `grep -iE 'error|fail|fatal' /tmp/install.linux.log || echo "no errors"`
Expected: `no errors`.

- [ ] **Step 3: Mac syntax-check (catches regressions before user tests on Mac)**

Run:
```bash
for f in install.sh zsh/.zshenv zsh/.zshrc zsh/.aliases; do
  zsh -n "/home/cyan/.config/.dotfiles/$f" && echo "OK $f" || echo "FAIL $f"
done
```
Expected: all four `OK`.

- [ ] **Step 4: Hand off to user for Mac verification**

Tell the user: "All Linux phases pass. Please run `zsh -n install.sh` on your Mac and re-run `install.sh` to confirm no regression. Report any unexpected diff."

---

## Self-Review Notes

**Spec coverage check:**
- ✔ `lib/common.sh` sourced library (mode 644, no exec) — Task 1
- ✔ `install.sh` refactored to source it — Task 2
- ✔ `install.linux.sh` phased structure — Tasks 8–13
- ✔ `apt/packages.txt` — Task 7
- ✔ Brewfile `if OS.mac?` guards — Task 6
- ✔ `.zshenv` OS branching — Task 3
- ✔ `.zshrc` (no-op confirmed) — Task 4
- ✔ `.aliases` darwin/linux branching — Task 5
- ✔ Phase 0 bootstrap — Task 8
- ✔ Phase 1 zsh — Task 9
- ✔ Phase 2 core CLI — Task 10
- ✔ Phase 3 mise + node — Task 11
- ✔ Phase 4 nvim — Task 12
- ✔ Phase 5 claude — Task 13
- ✔ Phase 6 docs — Task 14
- ✔ Mac regression prevention — Task 2 step 4 + Task 15 step 3

**Placeholder scan:** none.

**Type/name consistency:** function names `detect_os`, `create_link`, `ensure_dir`, `log_step`, `log_skip`, `log_done` are used consistently across Tasks 1, 8–13. `_dotfiles_copy` is defined once in Task 5 step 1 and referenced in steps 2/2/2/2 of the same task — consistent.

**Mac regression risk:** Tasks 2–6 all preserve existing macOS behavior (lines moved into `darwin*)` branch or `if OS.mac?` block, never deleted). Task 15 step 3 catches syntax breaks; user runs Mac smoke test in Task 2 step 4 / Task 15 step 4.
