#!/usr/bin/env bash
# install.linux.sh — WSL2/Ubuntu installer for the dotfiles repo.
# Counterpart to install.sh (macOS). Idempotent. Designed to be re-runnable.

# -E (errtrace): without it the ERR trap below stays silent for failures
# inside functions.
set -Eeuo pipefail

# Under set -e a mid-run death is easy to misread as success when the log is
# piped or backgrounded — print the failing line loudly instead.
trap 'echo "ERROR: install.linux.sh failed at line $LINENO: $BASH_COMMAND" >&2' ERR

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
  "$XDG_STATE_HOME/vim" \
  "$XDG_STATE_HOME/node" \
  "$XDG_STATE_HOME/python"

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

# /etc/skel leftovers (.bashrc, .profile, .bash_logout) — the default shell
# is zsh, nothing reads these. Delete only PRISTINE skel copies: a diff against
# /etc/skel guards against ever removing a file someone actually customized.
for f in .bashrc .profile .bash_logout; do
  if [ -f "$HOME/$f" ]; then
    if diff -q "/etc/skel/$f" "$HOME/$f" >/dev/null 2>&1; then
      rm "$HOME/$f"
      log_done "removed skel leftover: ~/$f"
    else
      log_skip "~/$f differs from /etc/skel — keeping"
    fi
  fi
done

create_link "$DOTFILES_PATH/zsh/.zshenv" "$HOME/.zshenv"
create_link "$DOTFILES_PATH/zsh/.zshrc"  "$XDG_CONFIG_HOME/zsh/.zshrc"
create_link "$DOTFILES_PATH/zsh/.aliases" "$XDG_CONFIG_HOME/zsh/.aliases"
[ -e "$XDG_CONFIG_HOME/zsh/zfunc" ] || ln -sf "$DOTFILES_PATH/zsh/zfunc" "$XDG_CONFIG_HOME/zsh/zfunc"

if [ ! -d "$XDG_CONFIG_HOME/zsh/oh-my-zsh" ]; then
  log_step "Installing oh-my-zsh"
  # CHSH=no: chsh is already handled above, and without it the installer
  # blocks on an interactive [Y/n] prompt when $SHELL isn't zsh yet
  # (i.e. every non-interactive first run on a fresh machine).
  ZSH="$XDG_CONFIG_HOME/zsh/oh-my-zsh" RUNZSH=no KEEP_ZSHRC=yes CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  update_repo "$XDG_CONFIG_HOME/zsh/oh-my-zsh"
fi

P10K_DIR="$XDG_CONFIG_HOME/zsh/oh-my-zsh/custom/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  git clone --depth=1 https://github.com/joresserwe/powerlevel10k.git "$P10K_DIR"
else
  update_repo "$P10K_DIR"
fi
create_link "$DOTFILES_PATH/zsh/.p10k.zsh" "$XDG_CONFIG_HOME/zsh/.p10k.zsh"

ZSH_AUTOSUG_DIR="$XDG_CONFIG_HOME/zsh/oh-my-zsh/custom/plugins/zsh-autosuggestions"
if [ ! -d "$ZSH_AUTOSUG_DIR" ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUG_DIR"
else
  update_repo "$ZSH_AUTOSUG_DIR"
fi

log_done "Phase 1 complete"

# ============================================================================
# Phase 2 — Core CLI (brew bundle + tool configs)
# ============================================================================
log_step "Phase 2: brew bundle (Linux subset) + tool configs"

# Homebrew >=6 refuses to install formulae from untrusted third-party taps
# (needed for arl/arl/gitmux). `|| true`: older brew has no `trust` command.
brew trust arl/arl 2>/dev/null || true

brew bundle install --file "$DOTFILES_PATH/brew/Brewfile"

create_link "$DOTFILES_PATH/git/config" "$XDG_CONFIG_HOME/git/config"

# WSL: make this clone pushable. The shared git/config routes github.com
# credentials to `gh auth git-credential`, which needs a per-machine login;
# fall through to Windows' Git Credential Manager via a repo-local override
# (helper reset + GCM). Symlinked into ~/.local/bin because a credential
# helper path can't contain spaces ("Program Files"). Machine state — the
# override lives in .git/config, never in the synced git/config.
GCM_WIN='/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe'
if [[ -n "${WSL_DISTRO_NAME:-}" ]] && [ -x "$GCM_WIN" ]; then
  ensure_dir "$HOME/.local/bin"
  ln -sfn "$GCM_WIN" "$HOME/.local/bin/git-credential-manager.exe"
  git -C "$DOTFILES_PATH" config --local --replace-all "credential.https://github.com.helper" ""
  git -C "$DOTFILES_PATH" config --local --add "credential.https://github.com.helper" "$HOME/.local/bin/git-credential-manager.exe"
  log_done "git: dotfiles clone credential fallback -> Windows GCM"
else
  log_skip "git credential bridge: not WSL or GCM missing"
fi
create_link "$DOTFILES_PATH/npm/npmrc"  "$XDG_CONFIG_HOME/npm/npmrc"

create_link "$DOTFILES_PATH/tmux/tmux.conf"         "$XDG_CONFIG_HOME/tmux/tmux.conf"
create_link "$DOTFILES_PATH/tmux/tmux.mapping.conf" "$XDG_CONFIG_HOME/tmux/tmux.mapping.conf"
create_link "$DOTFILES_PATH/tmux/gitmux.conf"       "$XDG_CONFIG_HOME/tmux/gitmux.conf"
create_link "$DOTFILES_PATH/tmux/smart-split.sh"    "$XDG_CONFIG_HOME/tmux/smart-split.sh"

create_link "$DOTFILES_PATH/atuin/config.toml" "$XDG_CONFIG_HOME/atuin/config.toml"

create_link "$DOTFILES_PATH/mise/config.toml" "$XDG_CONFIG_HOME/mise/config.toml"

# brew imagemagick has no font map; needed for SVG <text> rendering
create_link "$DOTFILES_PATH/imagemagick/type.xml" "$XDG_CONFIG_HOME/ImageMagick/type.xml"

create_link "$DOTFILES_PATH/yazi/yazi.toml"   "$XDG_CONFIG_HOME/yazi/yazi.toml"
create_link "$DOTFILES_PATH/yazi/theme.toml"  "$XDG_CONFIG_HOME/yazi/theme.toml"
create_link "$DOTFILES_PATH/yazi/keymap.toml" "$XDG_CONFIG_HOME/yazi/keymap.toml"
create_link "$DOTFILES_PATH/yazi/init.lua"    "$XDG_CONFIG_HOME/yazi/init.lua"
create_link "$DOTFILES_PATH/yazi/plugins/svg-code.yazi/main.lua" "$XDG_CONFIG_HOME/yazi/plugins/svg-code.yazi/main.lua"

# xdg-open shim (WSL-only): wslu/wslview is gone from Ubuntu 26.04 archives,
# so yazi's `open` opener routes through cmd.exe to the Windows default app.
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  ensure_dir "$HOME/.local/bin"
  ln -sfn "$DOTFILES_PATH/wsl/xdg-open" "$HOME/.local/bin/xdg-open"
  log_done "xdg-open shim -> wsl/xdg-open"
else
  log_skip "xdg-open shim: not running under WSL"
fi

# win32yank (WSL-only): clipboard tool for WSL. Preferred over clip.exe
# because it handles CRLF correctly and supports paste. Installed into
# ~/.local/bin (already on PATH via .zshenv). Pinned version for reproducibility.
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  WIN32YANK_BIN="$HOME/.local/bin/win32yank.exe"
  WIN32YANK_VERSION="v0.1.1"
  # The binary has no --version; a stamp file makes a pin bump reinstall on
  # the next re-run instead of being skipped forever.
  WIN32YANK_STAMP="$HOME/.local/bin/.win32yank.version"
  if [ ! -x "$WIN32YANK_BIN" ] || [ "$(cat "$WIN32YANK_STAMP" 2>/dev/null)" != "$WIN32YANK_VERSION" ]; then
    log_step "Installing win32yank ${WIN32YANK_VERSION}"
    ensure_dir "$HOME/.local/bin"
    tmp_zip="$(mktemp --suffix=.zip)"
    curl -fsSL -o "$tmp_zip" \
      "https://github.com/equalsraf/win32yank/releases/download/${WIN32YANK_VERSION}/win32yank-x64.zip"
    unzip -p "$tmp_zip" win32yank.exe > "$WIN32YANK_BIN"
    chmod +x "$WIN32YANK_BIN"
    rm -f "$tmp_zip"
    printf '%s' "$WIN32YANK_VERSION" > "$WIN32YANK_STAMP"
    log_done "win32yank installed: $WIN32YANK_BIN"
  else
    log_skip "win32yank already installed (${WIN32YANK_VERSION})"
  fi
else
  log_skip "win32yank: not running under WSL"
fi

# ~/Drives (WSL-only): symlink every Windows drive — local AND mapped network
# drives — under one directory. WSL automount covers only fixed local drives;
# link-drives.sh also drvfs-mounts anything else Windows reports (needs the
# NOPASSWD sudo this user already has). After mapping a NEW network drive in
# Windows, run ~/Drives/refresh.sh to pick it up — no reinstall needed.
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  if bash "$DOTFILES_PATH/wsl/link-drives.sh"; then
    log_done "drive links refreshed under ~/Drives"
  else
    log_skip "drive links: link-drives.sh failed (non-fatal)"
  fi
else
  log_skip "drive links: not running under WSL"
fi

# WezTerm (Windows side): write a stub at %USERPROFILE%\.wezterm.lua that
# dofile()s the config from the LOCAL dotfiles mirror (%USERPROFILE%\.dotfiles),
# not \\wsl.localhost — at first launch after boot the WSL VM may be down and
# a UNC dofile() fails, dropping wezterm to its default config.
# wezterm-watch.sh copies WSL-side edits into the mirror before touching the
# stub, so auto-reload still follows the clone.
if [[ -n "${WSL_DISTRO_NAME:-}" ]] && command -v cmd.exe >/dev/null 2>&1; then
  win_userprofile_raw="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
  if [[ -n "$win_userprofile_raw" ]]; then
    win_userprofile_wsl="$(wslpath "$win_userprofile_raw")"
    stub_path="$win_userprofile_wsl/.wezterm.lua"
    mirror_lua_path="${win_userprofile_raw}\\.dotfiles\\wezterm\\wezterm.lua"
    cat > "$stub_path" <<EOF
-- Auto-generated by install.linux.sh — do not edit by hand.
-- Delegates to the dotfiles mirror copy (synced from WSL ${WSL_DISTRO_NAME}).
-- Register the real file in WezTerm's reload watch list directly here, since
-- the Lua sandbox doesn't expose 'debug' and globals don't persist across reloads.
local wezterm = require 'wezterm'
local real_config = [[${mirror_lua_path}]]
wezterm.add_to_config_reload_watch_list(real_config)
return dofile(real_config)
EOF
    log_done "wezterm stub written: $stub_path -> $mirror_lua_path"

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

# WezTerm shell integration script (provides OSC 7/133/1337 for cwd tracking,
# prompt zones, and user vars). Sourced from .zshrc on WSL sessions.
WEZTERM_SH="$DOTFILES_PATH/wezterm/wezterm.sh"
WEZTERM_SH_URL="https://raw.githubusercontent.com/wez/wezterm/main/assets/shell-integration/wezterm.sh"
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  log_step "Downloading wezterm shell integration script"
  curl -fsSL "$WEZTERM_SH_URL" -o "$WEZTERM_SH"
  log_done "wezterm.sh updated: $WEZTERM_SH"
else
  log_skip "wezterm.sh: not running under WSL"
fi

# Windows-side packages (winget) and registry tweaks.
# Package list: winget/packages.txt, registry: winget/registry.ps1
if [[ -n "${WSL_DISTRO_NAME:-}" ]] && command -v winget.exe >/dev/null 2>&1; then
  # HARD REQUIREMENT: elevated interop. Windows interop processes inherit the
  # token of the terminal that launched this WSL session; without elevation,
  # Register-ScheduledTask -RunLevel Highest (glazewm/winkey/tacky autostart),
  # the HKLM Scancode Map in registry.ps1, and machine-scope winget installs
  # all fail SILENTLY behind the >/dev/null redirects below and the log
  # claims success. Fail loudly up front instead.
  if ! powershell.exe -NoProfile -Command \
      '([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)' \
      2>/dev/null | tr -d '\r' | grep -qi '^true$'; then
    echo "ERROR: Windows-side setup needs an ELEVATED terminal." >&2
    echo "  Open Windows Terminal (or wezterm) as Administrator, start this WSL" >&2
    echo "  distro from it, and re-run install.linux.sh." >&2
    exit 1
  fi
  log_step "winget: install packages from winget/packages.txt"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Parse "<id> [source]". Source defaults to winget.
    read -r pkg src <<<"$line"
    src="${src:-winget}"
    # Match installed packages by scanning full list: `winget list --id <id>`
    # doesn't reliably match msstore-style IDs (e.g. 9PFXXSHC64H3).
    # </dev/null on every winget.exe call: interop lets it drain our stdin,
    # which is packages.txt — without it the loop dies after the first entry.
    # tr -d '\0': winget emits UTF-16-ish output over interop; NULs break grep.
    if winget.exe list --accept-source-agreements </dev/null 2>/dev/null | tr -d '\0' | grep -q "$pkg"; then
      log_skip "winget: $pkg"
    else
      log_step "winget: installing $pkg (source: $src)"
      # Non-fatal: winget exits nonzero for "already installed, no upgrade".
      if winget.exe install --id "$pkg" --source "$src" \
        --accept-package-agreements --accept-source-agreements </dev/null; then
        log_done "winget: $pkg"
      else
        log_skip "winget: $pkg (exit $? — already installed or no applicable version)"
      fi
    fi
  done < "$DOTFILES_PATH/winget/packages.txt"

  log_step "ShareX: Start Menu capture shortcuts"
  powershell.exe -NoProfile -ExecutionPolicy Bypass \
    -File "$(wslpath -w "$DOTFILES_PATH/winget/sharex-shortcuts.ps1")" >/dev/null 2>&1 || true
  log_done "ShareX: Start Menu capture shortcuts"

  # --- Windows-local dotfiles mirror ----------------------------------------
  # Every Windows-side consumer reads from %USERPROFILE%\.dotfiles (exposed
  # as the DOTFILES_WIN user env var) instead of the \\wsl.localhost UNC. At
  # logon the WSL VM is not up, so UNC-based task actions / config paths are
  # dead on cold boot (observed 2026-07-15: glazewm crashed 0xc0000409,
  # zebar never started, tacky-borders ran configless). The mirror makes
  # logon self-contained; it is refreshed here and by winget/sync-windows.ps1
  # (first step of the Hyper+C reload chain). DOTFILES_UNC stays exported —
  # but only as the sync SOURCE, never dereferenced at logon.
  win_userprofile_raw="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
  if [[ -n "$win_userprofile_raw" ]]; then
    win_userprofile_wsl="$(wslpath "$win_userprofile_raw")"
    dotfiles_win_wsl="$win_userprofile_wsl/.dotfiles"
    dotfiles_win="${win_userprofile_raw}\\.dotfiles"
    mkdir -p "$dotfiles_win_wsl"
    # rsync without perms/owner flags — drvfs rejects chmod/chown metadata.
    # Keep this list in lockstep with winget/sync-windows.ps1.
    for d in glazewm zebar winget wezterm claude surfingkeys; do
      rsync -rlt --delete "$DOTFILES_PATH/$d/" "$dotfiles_win_wsl/$d/"
    done
    # tacky-borders/config.yaml is mirror-owned runtime state (rotate.ps1 and
    # the zsh tacky-theme helper write it) — exclude it so the sync can
    # neither overwrite nor delete it.
    rsync -rlt --delete --exclude 'config.yaml' \
      "$DOTFILES_PATH/tacky-borders/" "$dotfiles_win_wsl/tacky-borders/"
    if [[ ! -f "$dotfiles_win_wsl/tacky-borders/config.yaml" ]]; then
      cp "$DOTFILES_PATH/tacky-borders/themes/violet-pink.yaml" \
         "$dotfiles_win_wsl/tacky-borders/config.yaml"
      log_done "tacky-borders: mirror config.yaml bootstrapped (violet-pink)"
    fi
    cmd.exe /c setx DOTFILES_WIN "$dotfiles_win" >/dev/null 2>&1
    log_done "DOTFILES_WIN -> $dotfiles_win (mirror refreshed)"

    # Zero-flash launcher for every powershell-based logon task — see
    # winget/run-hidden.vbs. Console-subsystem task actions flash a window
    # at logon even with -WindowStyle Hidden.
    run_hidden_win="${dotfiles_win}\\winget\\run-hidden.vbs"

    # Claude Code (Windows side): render settings.windows.json into
    # %USERPROFILE%\.claude\settings.json with the machine's mirror path
    # substituted (the statusLine command needs an absolute path — no env
    # var expansion is guaranteed there). statusline.ps1 itself runs from
    # the mirror, so script edits propagate via the Hyper+C sync without
    # re-running this installer. The macOS/WSL counterpart is the shared
    # claude/settings.json symlink + claude/statusline.sh (jq-based).
    claude_win_dir="$win_userprofile_wsl/.claude"
    mkdir -p "$claude_win_dir"
    dotfiles_win_fwd="${dotfiles_win//\\//}"
    sed "s|__DOTFILES_WIN__|$dotfiles_win_fwd|g" \
      "$DOTFILES_PATH/claude/settings.windows.json" > "$claude_win_dir/settings.json"
    log_done "Claude Code (Windows): settings.json rendered (statusline -> $dotfiles_win_fwd/claude/statusline.ps1)"
  else
    log_skip "dotfiles mirror: could not resolve %USERPROFILE%"
  fi

  # GlazeWM config — dynamic generation model. The WSL-side config.yaml is a
  # TEMPLATE with BEGIN/END markers around workspaces + ws-keybindings;
  # generate-config.ps1 reads the template, expands to monitor_count × 3
  # workspaces (capped at 3 mons / 9 ws), and writes to the default live path
  # $USERPROFILE\.glzr\glazewm\config.yaml. Invoked from the Hyper+C chain.
  # GLAZEWM_CONFIG_PATH is NOT set here — glazewm falls back to the default
  # live path, which is what the generator writes. GLAZEWM_TEMPLATE_PATH tells
  # the generator where to read the template from (UNC -> WSL dotfiles).
  #
  # Helper ps1 scripts (reload-ahk, reload-indicator, reload-zebar, generate-
  # config, delayed-redraw) are NOT copied to $glzr_dir — config.yaml
  # references them via %DOTFILES_WIN%\glazewm\*.ps1 in the local mirror.
  # GlazeWM's shell-exec calls ShellExecuteExW, which expands %VAR% via
  # ExpandEnvironmentStringsW. The live $glzr_dir only holds the generated
  # config.yaml.
  if [[ -n "$win_userprofile_raw" ]]; then
    glzr_dir="$win_userprofile_wsl/.glzr/glazewm"
    mkdir -p "$glzr_dir"

    # Legacy cleanup: stale local copies of helper ps1 scripts from the
    # pre-UNC model. Safe to delete unconditionally — they're all referenced
    # only via %DOTFILES_WIN% in config.yaml now.
    for stale in delayed-redraw.ps1 reload-indicator.ps1 generate-config.ps1 \
                 reload-ahk.ps1 reload-zebar.ps1 tacky-reload.ps1; do
      rm -f "$glzr_dir/$stale"
    done

    # Template lives in the LOCAL mirror — generate-config.ps1 must be able
    # to read it at logon, before the WSL VM is up.
    glzr_template_win="${dotfiles_win}\\glazewm\\config.yaml"
    cmd.exe /c setx GLAZEWM_TEMPLATE_PATH "$glzr_template_win" >/dev/null 2>&1
    powershell.exe -NoProfile -Command "[Environment]::SetEnvironmentVariable('GLAZEWM_CONFIG_PATH', \$null, 'User')" >/dev/null 2>&1

    # DOTFILES_UNC — SYNC SOURCE ONLY (consumed by winget/sync-windows.ps1).
    # Runtime references all go through DOTFILES_WIN.
    dotfiles_unc="\\\\wsl.localhost\\${WSL_DISTRO_NAME}${DOTFILES_PATH//\//\\}"
    cmd.exe /c setx DOTFILES_UNC "$dotfiles_unc" >/dev/null 2>&1

    # Bootstrap the live config once so glazewm has something to read on
    # first start, even before the user presses Hyper+C.
    powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass \
      -File "$(wslpath -w "$DOTFILES_PATH/glazewm/generate-config.ps1")" >/dev/null 2>&1 || true

    log_done "GLAZEWM_TEMPLATE_PATH -> $glzr_template_win"
    log_done "DOTFILES_UNC -> $dotfiles_unc (sync source)"
    log_done "GlazeWM: live config bootstrapped at $glzr_dir/config.yaml; helpers via mirror"
  else
    log_skip "GlazeWM config: could not resolve %USERPROFILE%"
  fi

  # Zebar — reads widget pack + settings from the dotfiles mirror via
  # `--config-dir` (CLI flag supported by v3.3.x; see zebar/cli.rs).
  # Zebar has NO filesystem watcher (verified against v3.3.1 source — no
  # notify crate dep); reload-zebar.ps1 restarts it. The legacy local copy
  # under $USERPROFILE\.glzr\zebar\ is cleaned up here.
  if [[ -n "${win_userprofile_wsl:-}" ]]; then
    rm -rf "$win_userprofile_wsl/.glzr/zebar" \
      || log_skip "legacy .glzr/zebar removal failed (locked?) — non-fatal"
    log_done "Zebar: legacy local pack dir removed (config read from $dotfiles_win\\zebar via --config-dir)"
  fi

  # ShareX's personal folder is %LOCALAPPDATA%\ShareX (HKCU PersonalPath
  # override in winget/registry.ps1). The repo snapshot is applied on EVERY
  # run — seed-once meant a `git pull` with sharex/ changes never reached an
  # already-set-up machine. ShareX rewrites its JSONs on exit, so it must not
  # be running during the copy; restart it afterwards if it was. A pristine
  # copy of what was applied lands in the mirror (sharex.applied) so
  # winget/sync-windows.ps1 can reverse-capture only real GUI edits.
  sharex_personal_wsl="$win_userprofile_wsl/AppData/Local/ShareX"
  if [[ -n "${win_userprofile_wsl:-}" ]] && ls "$DOTFILES_PATH"/sharex/*.json >/dev/null 2>&1; then
    sharex_was_running="$(powershell.exe -NoProfile -Command \
      "[bool](Get-Process ShareX -ErrorAction SilentlyContinue)" 2>/dev/null | tr -d '\r')"
    if [[ "$sharex_was_running" == "True" ]]; then
      powershell.exe -NoProfile -Command \
        "Stop-Process -Name ShareX -Force -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 500" \
        >/dev/null 2>&1 || true
    fi
    mkdir -p "$sharex_personal_wsl" "$dotfiles_win_wsl/sharex.applied"
    cp "$DOTFILES_PATH"/sharex/*.json "$sharex_personal_wsl/"
    cp "$DOTFILES_PATH"/sharex/*.json "$dotfiles_win_wsl/sharex.applied/"
    log_done "ShareX: settings applied from sharex/ (pristine copy -> mirror sharex.applied)"
    if [[ "$sharex_was_running" == "True" ]]; then
      powershell.exe -NoProfile -Command \
        "Start-Process 'C:\Program Files\ShareX\ShareX.exe' -ArgumentList '-silent'" \
        >/dev/null 2>&1 || true
      log_done "ShareX: restarted (-silent)"
    fi
  fi

  # winkey.ahk — launched at login ONLY via Scheduled Task (RunLevel=Highest),
  # NOT via Startup-folder .lnk. The script runs from the local mirror
  # (%DOTFILES_WIN%\winget\winkey.ahk), so boot never depends on WSL/UNC.
  #
  # Why Task + Highest integrity, not Startup .lnk: glazewm runs at High
  # integrity (memory: project_winos_uipi_elevated_windows). When AHK installs
  # its WH_KEYBOARD_LL hook at Medium integrity (the default for Startup-folder
  # launches and RunLevel=Limited tasks), UIPI prevents the hook from receiving
  # keyboard events while a higher-integrity window (glazewm-managed tiles) is
  # foreground. Symptom: AHK process alive, TICK logging, but hotkeys never
  # fire. Confirmed 2026-04-24 by process integrity comparison — Task-spawned
  # AHK at Medium = dead hook; same binary re-spawned at High = working hook.
  # The earlier memory warning "Task Scheduler for AHK doesn't install hook"
  # was for RunLevel=Limited tasks specifically; Highest works the same as
  # tacky-borders' scheduled-task pattern.
  #
  # Dev-edit propagation: sync-windows.ps1 (first step of Hyper+C) refreshes
  # the mirror from the WSL clone, so edits to winget/winkey.ahk take effect
  # on the next Hyper+C without re-running install.linux.sh.
  win_appdata_raw="$(cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r')"
  win_userprofile_raw="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
  ahk_exe_win='C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
  ahk_exe_wsl='/mnt/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe'
  # Hard requirement, checked loudly: a user-scope AutoHotkey (unelevated
  # winget install) lands in %LOCALAPPDATA%\Programs instead, and the
  # Start-Process below would kill the whole script under set -e with the
  # error swallowed. reload-ahk.ps1 hardcodes the same machine-scope path.
  if [ ! -x "$ahk_exe_wsl" ]; then
    echo "ERROR: $ahk_exe_win not found — install machine-wide:" >&2
    echo "  winget install AutoHotkey.AutoHotkey --scope machine  (elevated)" >&2
    exit 1
  fi
  if [[ -n "$win_appdata_raw" && -n "$win_userprofile_raw" ]]; then
    win_appdata_wsl="$(wslpath "$win_appdata_raw")"
    win_userprofile_wsl="$(wslpath "$win_userprofile_raw")"
    startup_dir="$win_appdata_wsl/Microsoft/Windows/Start Menu/Programs/Startup"
    mkdir -p "$startup_dir"

    # winkey.ahk runs straight from the mirror — no per-file local copy.
    winkey_local_win="${dotfiles_win}\\winget\\winkey.ahk"

    # Legacy cleanup: old scheduled-task name, ~/.ahk/, raw Startup\winkey.ahk,
    # the Startup\winkey.lnk from the pre-Task architecture (2026-04-24
    # replaced with RunLevel=Highest Scheduled Task below to fix Medium→High
    # UIPI hook-event blocking), AND the ~/.config/winkey per-file copy dir
    # from the pre-mirror model.
    # `|| true`: SilentlyContinue suppresses the error but powershell.exe
    # still exits 1 when the task doesn't exist (fresh machine) — fatal
    # under set -e without the guard.
    powershell.exe -NoProfile -Command \
      "Unregister-ScheduledTask -TaskName winkey-ahk -Confirm:\$false -ErrorAction SilentlyContinue | Out-Null" \
      >/dev/null 2>&1 || true

    # Kill AHK BEFORE the legacy dir cleanup: on pre-mirror machines the
    # running instance has ~/.config/winkey as its CWD, which makes the
    # rm -rf below fail with Permission denied and kill the whole run under
    # set -e (observed 2026-07-18). The `|| true` guards cover any other
    # Windows-side lock — legacy leftovers must never abort an install.
    powershell.exe -NoProfile -Command "
      & taskkill.exe /F /IM AutoHotkey64.exe /T 2>&1 | Out-Null
      \$deadline = (Get-Date).AddSeconds(3)
      while ((Get-Date) -lt \$deadline -and (Get-Process AutoHotkey64 -EA SilentlyContinue)) {
        Start-Sleep -Milliseconds 100
      }
    " >/dev/null 2>&1 || true
    rm -rf "$win_userprofile_wsl/.ahk" || log_skip "legacy ~/.ahk removal failed (locked?) — non-fatal"
    rm -rf "$win_userprofile_wsl/.config/winkey" || log_skip "legacy .config/winkey removal failed (locked?) — non-fatal"
    rm -f "$startup_dir/winkey.ahk"
    rm -f "$startup_dir/winkey.lnk"

    # Live apply: spawn one High-integrity instance right now so the current
    # session isn't left without hotkeys between install and the next logon
    # (the AtLogon task's Highest launch is the sole owner from then on).
    powershell.exe -NoProfile -Command \
      "Start-Process -WindowStyle Hidden -FilePath '$ahk_exe_win' -ArgumentList '\"$winkey_local_win\"'" \
      >/dev/null 2>&1

    log_done "winkey.ahk: local copy @ $winkey_local_win (restarted; Startup .lnk removed — task launches now)"

    # Cold-boot diagnostic Scheduled Task. Fires AtLogon (no delay), script
    # self-samples system state at T+0/+30/+60/+120s into %TEMP%\cold-boot-
    # state.log. Lets us see whether Startup-folder .lnks fired, whether UNC
    # is reachable, process start times, registry state — paired with
    # %TEMP%\winkey-debug.log and %TEMP%\reload-ahk.log it answers "what
    # happened during the failing first 2 minutes post-login". Script path
    # MUST be local (not UNC) — at logon WSL VM isn't up yet so UNC is dead;
    # the mirror satisfies that.
    snapshot_local_win="${dotfiles_win}\\glazewm\\cold-boot-snapshot.ps1"
    powershell.exe -NoProfile -Command "
      \$act = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument '\"$run_hidden_win\" \"$snapshot_local_win\"'
      \$trg = New-ScheduledTaskTrigger -AtLogOn -User \$env:USERNAME
      \$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
      \$prn = New-ScheduledTaskPrincipal -UserId \$env:USERNAME -LogonType Interactive -RunLevel Limited
      Register-ScheduledTask -TaskName 'winkey-cold-boot-snapshot' -Action \$act -Trigger \$trg -Settings \$set -Principal \$prn -Force | Out-Null
    " >/dev/null 2>&1
    log_done "Scheduled Task 'winkey-cold-boot-snapshot' registered (AtLogon → $snapshot_local_win)"

    # Primary AHK launcher at logon: Scheduled Task (AtLogon, no delay,
    # RunLevel=Highest). This REPLACES the Startup-folder .lnk — see the
    # winkey comment block above for why Highest is required (glazewm is High
    # integrity; Medium-integrity AHK's WH_KEYBOARD_LL hook doesn't receive
    # events due to UIPI, so hotkeys silently don't fire). The task runs
    # reload-ahk.ps1 (local copy), which hard-kills any leftover AHK then
    # Start-Process-spawns a fresh one at High integrity (inherits from the
    # task's Highest-RunLevel PowerShell parent). Fires once per user logon.
    # No delay — AtLogon fires after the user token is created, and the task
    # itself (taskkill + Start-Process AHK) has no external dependencies.
    # Worst case: Explorer's Shell_TrayWnd isn't up yet when AHK runs, so the
    # initial HideShellTaskbars() no-ops — harmless, the TaskbarCreated
    # OnMessage hook re-hides on Explorer's later WM_TASKBARCREATED broadcast.
    reload_local_win="${dotfiles_win}\\glazewm\\reload-ahk.ps1"
    powershell.exe -NoProfile -Command "
      \$act = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument '\"$run_hidden_win\" \"$reload_local_win\"'
      \$trg = New-ScheduledTaskTrigger -AtLogOn -User \$env:USERNAME
      \$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
      \$prn = New-ScheduledTaskPrincipal -UserId \$env:USERNAME -LogonType Interactive -RunLevel Highest
      Register-ScheduledTask -TaskName 'winkey-cold-boot-autofix' -Action \$act -Trigger \$trg -Settings \$set -Principal \$prn -Force | Out-Null
    " >/dev/null 2>&1
    log_done "Scheduled Task 'winkey-cold-boot-autofix' registered (AtLogon, Highest → $reload_local_win)"
  else
    log_skip "winkey: could not resolve %APPDATA% or %USERPROFILE%"
  fi

  # GlazeWM auto-start via Scheduled Task (AtLogon, RunLevel=Highest). Replaces
  # the prior Startup-folder .lnk model. Rationale:
  # - Startup folder .lnks are intentionally throttled by Explorer ("idle task"
  #   scheduling) — on this machine GlazeWM.lnk used to fire ~80s post-boot,
  #   while tacky-borders (already on a task) fired ~60s. Moving GlazeWM to a
  #   task closes that gap.
  # - glazewm.exe self-elevates via its manifest (runs at High integrity); a
  #   Highest task matches that, so the spawned glazewm is consistent with the
  #   running state and there's no UAC prompt at logon.
  # - zebar is a child of glazewm (launched via startup_commands in
  #   config.yaml), so zebar timing follows glazewm automatically — no
  #   separate task needed.
  glazewm_exe_win='C:\Program Files\glzr.io\GlazeWM\glazewm.exe'
  glazewm_exe_wsl='/mnt/c/Program Files/glzr.io/GlazeWM/glazewm.exe'
  if [[ -x "$glazewm_exe_wsl" && -n "${startup_dir:-}" ]]; then
    # Legacy cleanup: delete the Startup-folder .lnk from the pre-task model.
    rm -f "$startup_dir/GlazeWM.lnk"
    # Action = glazewm/autostart.ps1 (mirror), NOT the exe directly:
    # - glazewm 3.10.1 sometimes aborts (0xc0000409) when launched right at
    #   logon while a later identical launch succeeds; the wrapper retries
    #   with backoff and captures the Rust panic stderr to
    #   %TEMP%\glazewm-autostart.log (the old `cmd /c start` discarded it).
    # - Direct task-action exec of the exe fails with 0x800702E4
    #   (requireAdministrator manifest vs Task Scheduler exec); Start-Process
    #   from the Highest-RunLevel PowerShell parent satisfies it cleanly.
    glazewm_autostart_win="${dotfiles_win}\\glazewm\\autostart.ps1"
    powershell.exe -NoProfile -Command "
      \$act = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument '\"$run_hidden_win\" \"$glazewm_autostart_win\"'
      \$trg = New-ScheduledTaskTrigger -AtLogOn -User \$env:USERNAME
      \$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
      \$prn = New-ScheduledTaskPrincipal -UserId \$env:USERNAME -LogonType Interactive -RunLevel Highest
      Register-ScheduledTask -TaskName 'winkey-glazewm-autostart' -Action \$act -Trigger \$trg -Settings \$set -Principal \$prn -Force | Out-Null
    " >/dev/null 2>&1
    log_done "Scheduled Task 'winkey-glazewm-autostart' registered (AtLogon, Highest → $glazewm_autostart_win)"

    # Restart a running glazewm through the task: a pre-existing instance
    # carries the env it was born with, so the setx'd vars above
    # (DOTFILES_WIN, GLAZEWM_TEMPLATE_PATH) are invisible to it — its
    # %DOTFILES_WIN% shell-exec rules then die in cmd ("The syntax of the
    # command is incorrect" console flashes) and the zebar startup_command
    # never comes up (observed 2026-07-18). Task Scheduler rebuilds the env
    # from the registry at launch, and zebar follows as a child.
    if powershell.exe -NoProfile -Command \
        "[bool](Get-Process glazewm -ErrorAction SilentlyContinue)" 2>/dev/null | tr -d '\r' | grep -qi '^true$'; then
      powershell.exe -NoProfile -Command "
        Stop-Process -Name glazewm -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-ScheduledTask -TaskName 'winkey-glazewm-autostart'
      " >/dev/null 2>&1 || true
      log_done "glazewm restarted via task (fresh env: DOTFILES_WIN et al.)"
    fi

    # GlazeWM binds TCP 6123 for IPC; Hyper-V/WSL's per-boot dynamic port
    # exclusion range can claim it first, and glazewm then aborts at logon
    # (0xc0000409 — observed on the 2026-07-15 cold boot). Add a persistent
    # winnat exclusion. Plain `netsh add` succeeds when 6123 isn't currently
    # inside an active dynamic range; if it fails, run
    # winget/reserve-glazewm-port.ps1 elevated AFTER `wsl --shutdown` (it
    # stops winnat/hns, which hangs while WSL is up).
    if netsh.exe int ipv4 add excludedportrange protocol=tcp startport=6123 numberofports=1 store=persistent </dev/null >/dev/null 2>&1; then
      log_done "TCP 6123 persistently reserved for GlazeWM IPC"
    else
      log_skip "TCP 6123 reservation: already reserved or range busy — if glazewm crashes at logon, run winget/reserve-glazewm-port.ps1 elevated after wsl --shutdown"
    fi
  else
    log_skip "GlazeWM task: glazewm.exe missing or startup_dir unset"
  fi

  # tacky-borders (Windows side): custom window borders with adjustable
  # width, gradients and fade animations. Not published to winget, so we
  # fetch the release zip directly (same pattern as win32yank above).
  #
  # Config: tacky-borders reads TACKY_BORDERS_CONFIG_HOME, pointed at the
  # local dotfiles mirror (%DOTFILES_WIN%\tacky-borders) — readable at logon
  # with WSL down, unlike the old UNC target. Themes sync from the WSL clone
  # via sync-windows.ps1; config.yaml is mirror-owned runtime state. Reload
  # still goes through Start-ScheduledTask, and
  # MultipleInstances=StopExisting (set in register-task.ps1) lets the Task
  # Scheduler service kill the running tacky-borders from LocalSystem
  # context regardless of UIPI. See register-task.ps1 and reload.ps1.
  #
  # Launch: Scheduled Task 'tacky-borders' with RunLevel=Highest (UIPI
  # blocks Medium->High SetWindowPos, so a Startup-folder launch couldn't
  # border GlazeWM-managed elevated windows). Action = tacky-borders.exe
  # directly (no wrapper -> no console flash).
  TACKY_VERSION="v1.4.1"
  if [[ -n "${win_userprofile_wsl:-}" ]]; then
    tacky_install_dir="$win_userprofile_wsl/tacky-borders"
    tacky_exe="$tacky_install_dir/tacky-borders.exe"
    # Stamp file: a TACKY_VERSION bump must reinstall on the next re-run —
    # exe presence alone skipped upgrades forever.
    tacky_stamp="$tacky_install_dir/.tacky-borders.version"
    if [ ! -x "$tacky_exe" ] || [ "$(cat "$tacky_stamp" 2>/dev/null)" != "$TACKY_VERSION" ]; then
      log_step "Installing tacky-borders ${TACKY_VERSION}"
      # A running instance locks the exe and the unzip would fail; the
      # scheduled task registered below brings it back up.
      powershell.exe -NoProfile -Command \
        "Stop-Process -Name tacky-borders -Force -ErrorAction SilentlyContinue" >/dev/null 2>&1 || true
      mkdir -p "$tacky_install_dir"
      tmp_zip="$(mktemp --suffix=.zip)"
      curl -fsSL -o "$tmp_zip" \
        "https://github.com/lukeyou05/tacky-borders/releases/download/${TACKY_VERSION}/tacky-borders-${TACKY_VERSION}.zip"
      unzip -o "$tmp_zip" -d "$tacky_install_dir" >/dev/null
      rm -f "$tmp_zip"
      printf '%s' "$TACKY_VERSION" > "$tacky_stamp"
      log_done "tacky-borders installed: $tacky_exe"
    else
      log_skip "tacky-borders already installed (${TACKY_VERSION})"
    fi

    # Live config.yaml is mirror-owned runtime state — bootstrapped by the
    # mirror block above; rotate.ps1 and the zsh tacky-theme helper write it.

    # Env var: TACKY_BORDERS_CONFIG_HOME -> local mirror. User-scope via setx
    # so newly spawned task processes inherit it on next launch. Readable at
    # logon (no WSL dependency), and the in-app ReadDirectoryChangesW watcher
    # works again on a real NTFS dir.
    tacky_cfg_home_win="${dotfiles_win}\\tacky-borders"
    cmd.exe /c setx TACKY_BORDERS_CONFIG_HOME "$tacky_cfg_home_win" >/dev/null 2>&1
    log_done "TACKY_BORDERS_CONFIG_HOME -> $tacky_cfg_home_win"

    # Legacy cleanup: prior cp model left themes + config.yaml under
    # %USERPROFILE%\.config\tacky-borders\; the intermediate symlink model
    # left an NTFS reparse point there. Either way, nuke it — env var now
    # points tacky-borders straight at the dotfiles dir.
    tacky_legacy_cfg_wsl="$win_userprofile_wsl/.config/tacky-borders"
    if [[ -e "$tacky_legacy_cfg_wsl" || -L "$tacky_legacy_cfg_wsl" ]]; then
      tacky_legacy_cfg_win="$(wslpath -w "$tacky_legacy_cfg_wsl")"
      powershell.exe -NoProfile -Command "
        \$p = '$tacky_legacy_cfg_win'
        if (Test-Path -LiteralPath \$p) {
          \$it = Get-Item -LiteralPath \$p -Force
          if (\$it.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            [IO.Directory]::Delete(\$p)
          } else {
            Remove-Item -LiteralPath \$p -Recurse -Force
          }
        }
      " >/dev/null 2>&1
      log_done "tacky-borders: removed legacy $tacky_legacy_cfg_win"
    fi

    # Drop any legacy Startup-folder shortcut from the pre-task launch model.
    if [[ -n "${startup_dir:-}" && -e "$startup_dir/tacky-borders.lnk" ]]; then
      rm -f "$startup_dir/tacky-borders.lnk"
      log_done "tacky-borders: removed legacy Startup shortcut"
    fi

    # Clean up legacy local rotate.ps1 copy — now referenced via UNC.
    rm -rf "$win_userprofile_wsl/.glzr/tacky-borders"

    # Register the main task. Action = wscript.exe <mirror launch.vbs>; the
    # VBS does taskkill+wait+launch under Highest so reload is atomic and
    # silent (no console flash, no "already running" dialog). Mirror path is
    # readable at logon — the AtLogon trigger works on cold boot.
    tacky_launch_vbs_win="${dotfiles_win}\\tacky-borders\\launch.vbs"
    powershell.exe -NoProfile -ExecutionPolicy Bypass \
      -File "$(wslpath -w "$DOTFILES_PATH/tacky-borders/register-task.ps1")" \
      -ExePath "$(wslpath -w "$tacky_exe")" \
      -LaunchVbs "$tacky_launch_vbs_win" >/dev/null 2>&1
    log_done "tacky-borders scheduled task registered (AtLogOn, Highest) -> $tacky_launch_vbs_win"

    # Daily theme rotator: AtLogOn + Daily 00:05 calls rotate.ps1 from the
    # mirror. rotate.ps1 reads/writes via TACKY_BORDERS_CONFIG_HOME, then
    # Start-ScheduledTask's tacky-borders.
    tacky_rotate_win="${dotfiles_win}\\tacky-borders\\rotate.ps1"
    powershell.exe -NoProfile -ExecutionPolicy Bypass \
      -File "$(wslpath -w "$DOTFILES_PATH/tacky-borders/register-rotate-task.ps1")" \
      -ScriptPath "$tacky_rotate_win" >/dev/null 2>&1
    log_done "tacky-borders daily rotator registered (mirror) -> $tacky_rotate_win"
  else
    log_skip "tacky-borders: could not resolve %USERPROFILE%"
  fi

  # Apply Windows registry tweaks + AppX cleanup: CapsLock→Ctrl, Win+L/D/U
  # blocks, taskbar auto-hide, Xbox Game Bar removal. See winget/registry.ps1.
  log_step "Applying Windows registry tweaks"
  powershell.exe -NoProfile -ExecutionPolicy Bypass \
    -File "$(wslpath -w "$DOTFILES_PATH/winget/registry.ps1")" >/dev/null 2>&1
  log_done "Registry tweaks applied (some require next login)"
else
  log_skip "winget: not running under WSL or winget.exe unavailable"
fi

# trash-cli zsh completions — the Ubuntu package ships none, but each command
# can emit its own via shtab (python3-shtab, from apt/packages.txt). Written to
# a user site-functions dir that .zshrc prepends to fpath before compinit.
# The #compdef header check filters out both unsupported subcommands (trash-rm)
# and the "Please install shtab firstly!" plea shtab-less builds print.
ZSH_SITE_FUNCS="$XDG_DATA_HOME/zsh/site-functions"
ensure_dir "$ZSH_SITE_FUNCS"
for c in trash trash-put trash-empty trash-list trash-restore trash-rm; do
  if command -v "$c" >/dev/null 2>&1 \
     && "$c" --print-completion zsh > "$ZSH_SITE_FUNCS/_$c" 2>/dev/null \
     && head -1 "$ZSH_SITE_FUNCS/_$c" | grep -q '^#compdef'; then
    log_done "zsh completion: _$c"
  else
    rm -f "$ZSH_SITE_FUNCS/_$c"
    log_skip "zsh completion: $c (generation unsupported)"
  fi
done

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
    yazi-rs/plugins:smart-enter \
    Reledia/glow \
    yazi-rs/flavors:catppuccin-mocha; do
    ya pkg add "$pkg" || log_skip "ya pkg add $pkg (already installed or failed)"
  done
else
  log_skip "ya command not found; skip yazi plugin install"
fi

log_done "Phase 2 complete"

# ============================================================================
# Phase 3 — Runtime (mise + node/java + global pnpm packages)
# ============================================================================
log_step "Phase 3: mise + node/java + global packages"

eval "$(mise activate bash)"
mise use -g node@lts
mise use -g java@temurin-21
# mise activate hooks fire on prompt; in non-interactive bash we must add shims to PATH manually
export PATH="$XDG_DATA_HOME/mise/shims:$PATH"

export PNPM_HOME="${PNPM_HOME:-$XDG_DATA_HOME/pnpm}"
# $PNPM_HOME/bin too: pnpm >=10 places the global bin dir there and refuses
# `install -g` when it's not in PATH.
export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"

for pkg in yarn npm-check-updates mcp-hub; do
  if pnpm list -g --depth=0 2>/dev/null | grep -q "$pkg"; then
    log_skip "pnpm global: $pkg"
  else
    # </dev/null: pnpm >=10 blocks on an interactive build-approval picker
    # when a TTY is attached, and CI=1 alone does NOT suppress it (verified
    # on pnpm 11.13). Non-interactive stdin forces the prompt to auto-skip;
    # build scripts stay ignored — none of these CLI tools need theirs.
    CI=1 pnpm install -g "$pkg" </dev/null
    log_done "pnpm global: $pkg"
  fi
done

log_done "Phase 3 complete"

# ============================================================================
# Phase 4 — Editor (nvim-config)
# ============================================================================
log_step "Phase 4: nvim config"

NVIM_DIR="$XDG_CONFIG_HOME/nvim"
NVIM_REPO="https://github.com/joresserwe/nvim-config"
NVIM_REPO_OLD="https://github.com/joresserwe/astronvim_config"

if [ -d "$NVIM_DIR/.git" ]; then
  REMOTE="$(git -C "$NVIM_DIR" config --get remote.origin.url 2>/dev/null || echo)"
  if [ "$REMOTE" = "$NVIM_REPO" ] || [ "$REMOTE" = "${NVIM_REPO}.git" ]; then
    update_repo "$NVIM_DIR"
  elif [ "$REMOTE" = "$NVIM_REPO_OLD" ] || [ "$REMOTE" = "${NVIM_REPO_OLD}.git" ]; then
    git -C "$NVIM_DIR" remote set-url origin "$NVIM_REPO"
    log_done "nvim remote updated to renamed repo"
    update_repo "$NVIM_DIR"
  else
    log_step "Backing up existing nvim dir to nvim_backup_$(date +%s)"
    mv "$NVIM_DIR" "${NVIM_DIR}_backup_$(date +%s)"
    git clone "$NVIM_REPO" "$NVIM_DIR"
  fi
elif [ -d "$NVIM_DIR" ]; then
  log_step "Backing up existing non-git nvim dir to nvim_backup_$(date +%s)"
  mv "$NVIM_DIR" "${NVIM_DIR}_backup_$(date +%s)"
  git clone "$NVIM_REPO" "$NVIM_DIR"
else
  git clone "$NVIM_REPO" "$NVIM_DIR"
fi

log_done "Phase 4 complete (run 'nvim --headless \"+Lazy! sync\" +qa' to pre-install plugins)"

# ============================================================================
# Phase 5 — Claude Code
# ============================================================================
log_step "Phase 5: Claude Code"

# Claude Code CLI — native installer, lands in ~/.local/bin/claude (same
# convention as win32yank; .zshenv already puts ~/.local/bin on PATH) and
# self-updates from then on. `command -v` alone isn't enough here: this
# script runs under bash without .zshenv, so probe the install path too.
# A Windows-side claude resolved through interop (/mnt/c/...) must NOT
# satisfy the probe — WSL needs its own native binary.
claude_on_path="$(command -v claude 2>/dev/null || true)"
if [ -x "$HOME/.local/bin/claude" ] || { [ -n "$claude_on_path" ] && [[ "$claude_on_path" != /mnt/* ]]; }; then
  log_skip "claude CLI already installed"
else
  log_step "Installing Claude Code CLI (native installer)"
  curl -fsSL https://claude.ai/install.sh | bash
  log_done "claude CLI installed: $HOME/.local/bin/claude"
fi

ensure_dir "$XDG_DATA_HOME/claude"

create_link "$DOTFILES_PATH/claude/settings.json" "$XDG_DATA_HOME/claude/settings.json"
create_link "$DOTFILES_PATH/claude/CLAUDE.md" "$XDG_DATA_HOME/claude/CLAUDE.md"

# Legacy (pre-2026-07): ~/.claude was a symlink to $XDG_DATA_HOME/claude.
# Through that link the create_link below would land on the XDG settings.json
# and clobber it with settings.home.json. CLAUDE_CONFIG_DIR (.zshenv) made
# the link obsolete — drop it so ~/.claude becomes a real directory.
if [ -L "$HOME/.claude" ]; then
  rm "$HOME/.claude"
  log_done "removed legacy ~/.claude symlink"
fi
create_link "$DOTFILES_PATH/claude/settings.home.json" "$HOME/.claude/settings.json"

if [ -L "$XDG_DATA_HOME/claude/skills" ] || [ ! -e "$XDG_DATA_HOME/claude/skills" ]; then
  ln -sfn "$DOTFILES_PATH/claude/skills" "$XDG_DATA_HOME/claude/skills"
  log_done "link: $XDG_DATA_HOME/claude/skills -> $DOTFILES_PATH/claude/skills"
else
  log_skip "$XDG_DATA_HOME/claude/skills exists and is not a symlink — leaving alone"
fi

log_done "Phase 5 complete"

# ============================================================================
log_step "All phases complete. Open a new shell (or 'exec zsh') to start using it."

log_step "Manual step — Surfingkeys (per browser)"
log_manual "In the extension settings, set 'Load settings from' to:"
log_manual "  https://raw.githubusercontent.com/joresserwe/dotfiles/master/surfingkeys/config.js"
