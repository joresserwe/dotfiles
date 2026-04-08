# WSL Dotfiles Port — Design

Date: 2026-04-08
Status: Approved (design phase)

## Goal

Bring the existing macOS dotfiles repo (`~/.config/.dotfiles`) to WSL2 Ubuntu so a single command on a fresh WSL install reproduces a Mac-equivalent CLI development environment (zsh, nvim, tmux, yazi, atuin, mise, claude, …), while preserving the existing macOS `install.sh` behavior with **zero regression**.

## Non-Goals

- Native Windows (PowerShell) automation. Scope is inside WSL2 Ubuntu only.
- Auto-installing Linux replacements for macOS-only tools (aerospace, karabiner, yabai, raycast, wallpaperkiller).
- GUI font installation. Nerd Font setup on Windows Terminal / wezterm-windows is documented manually.
- `defaults write` equivalents on Linux.

## Core Principles

1. **No macOS regression.** The current `install.sh` remains functionally identical. Shared files only *add* a Linux branch; existing Mac lines stay byte-equivalent inside a darwin guard.
2. **Single source of truth.** Each tool has one config file. OS differences live inline as runtime branches (`case $OSTYPE`, `if OS.mac?`), not as duplicated files.
3. **XDG-first.** All paths use `$XDG_*`. Tools without native XDG support are forced via env vars in `.zshenv`.
4. **Folder = tool.** One folder, one tool's full responsibility (config + helper scripts). No `darwin/` / `linux/` split folders.
5. **Idempotent.** Both installers are safe to re-run.
6. **Hybrid package strategy.** apt for system/build dependencies; Homebrew on Linux for up-to-date CLI tools. Brewfile is shared via `if OS.mac?` / `if OS.linux?` blocks.

## Repository Layout (changes only)

```
~/.config/.dotfiles/
├── install.sh             # (existing, macOS) — refactored to source lib/common.sh; behavior unchanged
├── install.linux.sh       # (new) WSL/Ubuntu entrypoint
├── lib/
│   └── common.sh          # (new) sourced-only library: create_link, ensure_dir, detect_os, log_*
├── apt/
│   └── packages.txt       # (new) Linux-only apt packages (build-essential, zsh, curl, unzip, ...)
├── brew/
│   └── Brewfile           # (modified) wrap Mac-only entries in `if OS.mac?`; add `if OS.linux?` block if needed
├── zsh/
│   ├── .zshenv            # (modified) `case $OSTYPE` for XDG_RUNTIME_DIR, HOMEBREW_PREFIX, etc.
│   ├── .zshrc             # (modified) OS-guarded plugin/init
│   └── .aliases           # (modified) macOS-only aliases gated under darwin
├── tmux/                  # (modified) clipboard/open commands branched by OS
├── git/                   # unchanged
├── (mac-only folders untouched: aerospace/, karabiner/, yabai/, raycast/, wallpaperkiller/)
└── docs/superpowers/specs/2026-04-08-wsl-dotfiles-port-design.md   # this file
```

`install.linux.sh` does not touch the mac-only folders. They remain in the repo and are linked only by `install.sh` on macOS.

## `lib/common.sh` — Sourced Library

- File mode `644` (no execute bit). It is a *library*, not a script.
- Contains function definitions only — no top-level side effects.
- Both `install.sh` and `install.linux.sh` source it: `source "$DOTFILES_PATH/lib/common.sh"`.
- Functions:
  - `detect_os()` → echoes `darwin` or `linux`
  - `create_link target link_path` → mkdir -p parent, `ln -sf` (identical to current `create_link` in install.sh)
  - `ensure_dir path...` → `mkdir -p` with idempotent log
  - `log_step msg`, `log_skip msg`, `log_done msg` → consistent step output

The existing `install.sh` is refactored to call these functions. The refactor is mechanical (function extraction) and produces no behavioral diff on macOS.

## `install.linux.sh` — Phased Structure

Each phase is independent, idempotent, and committed separately. The user can verify after every phase.

### Phase 0 — Bootstrap
- Set XDG env defaults (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`, `XDG_RUNTIME_DIR=/run/user/$UID`).
- Create XDG directories via `ensure_dir`.
- `sudo apt update && sudo apt install -y` from `apt/packages.txt` (build-essential, curl, git, unzip, zsh, ca-certificates, file, procps).
- Install Homebrew on Linux if not present; add `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` to current session.
- Verify dotfiles repo exists at `$XDG_CONFIG_HOME/.dotfiles` (clone if missing).
- Source `lib/common.sh`.

### Phase 1 — Shell (zsh)
- `chsh -s "$(which zsh)"` if not already zsh.
- `create_link` for `zsh/.zshenv` → `~/.zshenv`, `.zshrc` → `$XDG_CONFIG_HOME/zsh/.zshrc`, `.aliases`, `zfunc/`.
- Install oh-my-zsh into `$XDG_CONFIG_HOME/zsh/oh-my-zsh` (same env vars as macOS path).
- Clone powerlevel10k and zsh-autosuggestions into oh-my-zsh custom dirs (idempotent guards).
- Link `zsh/.p10k.zsh`.

### Phase 2 — Core CLI
- `brew bundle install --file "$DOTFILES_PATH/brew/Brewfile"` — Linux-relevant entries install, Mac-only blocks skipped automatically by `OS.mac?`.
- `create_link` for git config, tmux configs, atuin config, yazi configs.
- Run `ya pkg add ...` set (same as macOS).

### Phase 3 — Runtime (mise + node)
- `eval "$(mise activate zsh)"`, `mise use -g node@lts`.
- Install pnpm-managed globals: `yarn`, `npm-check-updates`, `mcp-hub`.

### Phase 4 — Editor (nvim)
- If `$XDG_CONFIG_HOME/nvim` exists and is not a clone of the dotfiles nvim repo, move to `nvim_backup`.
- `git clone https://github.com/joresserwe/astronvim_config "$XDG_CONFIG_HOME/nvim"`.
- Headless `nvim --headless "+Lazy! sync" +qa` to pre-install plugins (optional; can be deferred to first launch).

### Phase 5 — Claude Code
- `create_link "$DOTFILES_PATH/claude/settings.json" "$XDG_DATA_HOME/claude/settings.json"`.
- `ln -sf "$DOTFILES_PATH/claude/skills" "$XDG_DATA_HOME/claude/skills"`.
- `ln -sf "$XDG_DATA_HOME/claude" ~/.claude` (workaround for Claude Code not fully respecting XDG — same as macOS).

### Phase 6 — Windows-side notes (docs only, no script actions)
- README section: install Nerd Font in Windows Terminal / wezterm-windows; recommended Windows Terminal profile that launches into WSL zsh; clipboard integration via `clip.exe` already handled by tmux/nvim configs.

## Inline OS-Branch Patterns

### `zsh/.zshenv`
```sh
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

case "$OSTYPE" in
  darwin*)
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$HOME/Library/Caches/Runtime}"
    export HOMEBREW_PREFIX="/opt/homebrew"
    ;;
  linux*)
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
    export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    ;;
esac
[ -x "$HOMEBREW_PREFIX/bin/brew" ] && eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
```

### `brew/Brewfile`
```ruby
# common
brew "git"
brew "neovim"
brew "tmux"
brew "yazi"
brew "atuin"
brew "mise"
# ...

if OS.mac?
  cask "wezterm"
  cask "raycast"
  brew "koekeishiya/formulae/yabai"
  # ... all existing Mac-only entries moved here verbatim
end

if OS.linux?
  # Linux-only additions, if any
end
```

### `zsh/.aliases`
```sh
alias ll='eza -lah'
case "$OSTYPE" in
  darwin*) alias o='open' ;;
  linux*)  alias o='xdg-open' ;;
esac
```

## macOS Regression Prevention

- Phase 0 modifies `install.sh` only by extracting functions into `lib/common.sh` and sourcing it. Behavior is byte-equivalent.
- Edits to shared files (`.zshenv`, `.zshrc`, `.aliases`, `Brewfile`, `tmux.conf`) wrap **existing lines unchanged inside a darwin guard**, then add a new linux guard alongside. No existing Mac line is rewritten or moved out of its semantic position.
- After each shared-file edit, manual checklist: re-source on macOS and confirm no errors.

## YAGNI / Out of Scope

- Native Windows automation
- Linux replacements for aerospace/karabiner/yabai/raycast/wallpaperkiller
- GUI font auto-install
- `defaults write` equivalents
- Multi-distro support (only Ubuntu on WSL2 is targeted)

## Open Questions

None at design time.
