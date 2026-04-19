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

create_link "$DOTFILES_PATH/mise/config.toml" "$XDG_CONFIG_HOME/mise/config.toml"

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
  log_step "winget: install packages from winget/packages.txt"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Parse "<id> [source]". Source defaults to winget.
    read -r pkg src <<<"$line"
    src="${src:-winget}"
    # Match installed packages by scanning full list: `winget list --id <id>`
    # doesn't reliably match msstore-style IDs (e.g. 9PFXXSHC64H3).
    if winget.exe list --accept-source-agreements 2>/dev/null | grep -q "$pkg"; then
      log_skip "winget: $pkg"
    else
      log_step "winget: installing $pkg (source: $src)"
      winget.exe install --id "$pkg" --source "$src" \
        --accept-package-agreements --accept-source-agreements
      log_done "winget: $pkg"
    fi
  done < "$DOTFILES_PATH/winget/packages.txt"

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
  # config, delayed-redraw) are NOT copied to $glzr_dir anymore — config.yaml
  # references them directly via %DOTFILES_UNC%\glazewm\*.ps1. GlazeWM's
  # shell-exec calls ShellExecuteExW, which handles UNC fine and expands any
  # %VAR% via ExpandEnvironmentStringsW. The live $glzr_dir only holds the
  # generated config.yaml.
  win_userprofile_raw="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
  if [[ -n "$win_userprofile_raw" ]]; then
    win_userprofile_wsl="$(wslpath "$win_userprofile_raw")"
    glzr_dir="$win_userprofile_wsl/.glzr/glazewm"
    mkdir -p "$glzr_dir"

    # Legacy cleanup: stale local copies of helper ps1 scripts from the
    # pre-UNC model. Safe to delete unconditionally — they're all referenced
    # only via %DOTFILES_UNC% in config.yaml now.
    for stale in delayed-redraw.ps1 reload-indicator.ps1 generate-config.ps1 \
                 reload-ahk.ps1 reload-zebar.ps1 tacky-reload.ps1; do
      rm -f "$glzr_dir/$stale"
    done

    # UNC paths for env vars.
    glzr_unc_template="\\\\wsl.localhost\\${WSL_DISTRO_NAME}${DOTFILES_PATH//\//\\}\\glazewm\\config.yaml"
    cmd.exe /c setx GLAZEWM_TEMPLATE_PATH "$glzr_unc_template" >/dev/null 2>&1
    powershell.exe -NoProfile -Command "[Environment]::SetEnvironmentVariable('GLAZEWM_CONFIG_PATH', \$null, 'User')" >/dev/null 2>&1

    # DOTFILES_UNC — every helper ps1 + config.yaml shell-exec reference uses
    # it; the zebar --config-dir / tacky-borders symlink target both derive
    # from this root. Setting it as a User env var makes it resolvable from
    # GlazeWM's process env (Explorer-launched child inherits at logon).
    dotfiles_unc="\\\\wsl.localhost\\${WSL_DISTRO_NAME}${DOTFILES_PATH//\//\\}"
    cmd.exe /c setx DOTFILES_UNC "$dotfiles_unc" >/dev/null 2>&1

    # Bootstrap the live config once so glazewm has something to read on
    # first start, even before the user presses Hyper+C.
    powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass \
      -File "$(wslpath -w "$DOTFILES_PATH/glazewm/generate-config.ps1")" >/dev/null 2>&1 || true

    log_done "GLAZEWM_TEMPLATE_PATH -> $glzr_unc_template"
    log_done "DOTFILES_UNC -> $dotfiles_unc"
    log_done "GlazeWM: live config bootstrapped at $glzr_dir/config.yaml; helpers via UNC"
  else
    log_skip "GlazeWM config: could not resolve %USERPROFILE%"
  fi

  # Zebar — reads widget pack + settings directly from the dotfiles UNC root
  # via `--config-dir` (CLI flag supported by v3.3.x; see zebar/cli.rs).
  # Zebar has NO filesystem watcher (verified against v3.3.1 source — no
  # notify crate dep), so UNC read is fully supported. The legacy local copy
  # under $USERPROFILE\.glzr\zebar\ is cleaned up here.
  if [[ -n "${win_userprofile_wsl:-}" ]]; then
    rm -rf "$win_userprofile_wsl/.glzr/zebar"
    log_done "Zebar: legacy local pack dir removed (config read from $dotfiles_unc\\zebar via --config-dir)"
  fi

  # winkey.ahk — launched at login via a Startup-folder .lnk whose Target is
  # AutoHotkey64.exe and whose Arguments is the WSL-dotfiles UNC path to the
  # script. No local copy is kept: the .lnk is resolved locally by Explorer,
  # then AutoHotkey64.exe reads the .ahk over UNC — and unlike Explorer's old
  # .ahk file association (via the AutoHotkeyUX launcher), AutoHotkey64.exe
  # handles UNC fine. This makes winget/winkey.ahk in the dotfiles repo the
  # single source of truth. The script's 30s self-relaunch (inside winkey.ahk)
  # is kept as a secondary safety net against the hook-install race on very
  # cold boots. Task Scheduler was tried historically but its launched process
  # couldn't install the hook; that cleanup remains here.
  win_appdata_raw="$(cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r')"
  win_userprofile_raw="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
  ahk_exe_win='C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
  ahk_exe_wsl='/mnt/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe'
  if [[ -n "$win_appdata_raw" && -n "$win_userprofile_raw" ]]; then
    win_appdata_wsl="$(wslpath "$win_appdata_raw")"
    win_userprofile_wsl="$(wslpath "$win_userprofile_raw")"
    startup_dir="$win_appdata_wsl/Microsoft/Windows/Start Menu/Programs/Startup"
    mkdir -p "$startup_dir"

    # UNC path to the script in the dotfiles repo. dotfiles_unc is set just
    # above for GlazeWM helpers — reuse it verbatim so both agree on the root.
    winkey_ahk_unc="${dotfiles_unc}\\winget\\winkey.ahk"

    # Legacy cleanup: old Task Scheduler entry, ~/.ahk/ dir from the task
    # model, the raw .ahk that earlier installs dropped directly in Startup,
    # and the stale local copy at ~/.config/winkey from the interim copy model.
    powershell.exe -NoProfile -Command \
      "Unregister-ScheduledTask -TaskName winkey-ahk -Confirm:\$false -ErrorAction SilentlyContinue | Out-Null" \
      >/dev/null 2>&1
    rm -rf "$win_userprofile_wsl/.ahk"
    rm -rf "$win_userprofile_wsl/.config/winkey"
    rm -f "$startup_dir/winkey.ahk"

    # Startup .lnk: AutoHotkey64.exe "<UNC winkey.ahk>". Reuses the generic
    # install-startup.ps1 helper (-ExePath / -LinkPath / -Arguments).
    if [[ -x "$ahk_exe_wsl" ]]; then
      winkey_lnk="$startup_dir/winkey.lnk"
      powershell.exe -NoProfile -ExecutionPolicy Bypass \
        -File "$(wslpath -w "$DOTFILES_PATH/tacky-borders/install-startup.ps1")" \
        -ExePath "$ahk_exe_win" \
        -LinkPath "$(wslpath -w "$winkey_lnk")" \
        -Arguments "\"$winkey_ahk_unc\"" >/dev/null 2>&1
      log_done "winkey.lnk -> AutoHotkey64.exe $winkey_ahk_unc"
    else
      log_skip "winkey.lnk: AutoHotkey64.exe missing at $ahk_exe_win"
    fi

    # Live-reload any already-running AHK so edits land without waiting for
    # the next login (winkey.ahk's signal-file poller consumes the touch).
    win_temp_raw="$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')"
    [[ -n "$win_temp_raw" ]] && touch "$(wslpath "$win_temp_raw")/winkey-reload.signal"

    log_done "winkey.ahk: UNC source of truth @ $winkey_ahk_unc (reload signal sent)"
  else
    log_skip "winkey: could not resolve %APPDATA% or %USERPROFILE%"
  fi

  # GlazeWM auto-start via Startup folder shortcut. Reuses the generic
  # install-startup.ps1 from tacky-borders/ (takes -ExePath / -LinkPath).
  glazewm_exe_win='C:\Program Files\glzr.io\GlazeWM\glazewm.exe'
  glazewm_exe_wsl='/mnt/c/Program Files/glzr.io/GlazeWM/glazewm.exe'
  if [[ -x "$glazewm_exe_wsl" && -n "${startup_dir:-}" ]]; then
    glazewm_lnk="$startup_dir/GlazeWM.lnk"
    powershell.exe -NoProfile -ExecutionPolicy Bypass \
      -File "$(wslpath -w "$DOTFILES_PATH/tacky-borders/install-startup.ps1")" \
      -ExePath "$glazewm_exe_win" \
      -LinkPath "$(wslpath -w "$glazewm_lnk")" >/dev/null 2>&1
    log_done "GlazeWM startup shortcut: $glazewm_lnk"
  else
    log_skip "GlazeWM startup: glazewm.exe missing or startup_dir unset"
  fi

  # tacky-borders (Windows side): custom window borders with adjustable
  # width, gradients and fade animations. Not published to winget, so we
  # fetch the release zip directly (same pattern as win32yank above).
  #
  # Config: tacky-borders reads TACKY_BORDERS_CONFIG_HOME (supports UNC),
  # which we point at the WSL dotfiles tacky-borders dir. No local copy, no
  # symlink — the repo is the source of truth. The in-app file watcher uses
  # Win32 ReadDirectoryChangesW which doesn't fire over WSL's 9P redirector
  # (microsoft/WSL#4581), so hot-reload on config edit is dead by design;
  # reload instead goes through Start-ScheduledTask, and
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
    if [ ! -x "$tacky_exe" ]; then
      log_step "Installing tacky-borders ${TACKY_VERSION}"
      mkdir -p "$tacky_install_dir"
      tmp_zip="$(mktemp --suffix=.zip)"
      curl -fsSL -o "$tmp_zip" \
        "https://github.com/lukeyou05/tacky-borders/releases/download/${TACKY_VERSION}/tacky-borders-${TACKY_VERSION}.zip"
      unzip -o "$tmp_zip" -d "$tacky_install_dir" >/dev/null
      rm -f "$tmp_zip"
      log_done "tacky-borders installed: $tacky_exe"
    else
      log_skip "tacky-borders already installed"
    fi

    # Bootstrap dotfiles config.yaml if missing. Gitignored, rotating state;
    # seeded from violet-pink on first install.
    dotfiles_cfg="$DOTFILES_PATH/tacky-borders/config.yaml"
    if [[ ! -f "$dotfiles_cfg" ]]; then
      cp "$DOTFILES_PATH/tacky-borders/themes/violet-pink.yaml" "$dotfiles_cfg"
      log_done "tacky-borders: bootstrapped dotfiles config.yaml (violet-pink)"
    else
      log_skip "tacky-borders: dotfiles config.yaml already present"
    fi

    # Env var: TACKY_BORDERS_CONFIG_HOME -> UNC dotfiles. User-scope via setx
    # so newly spawned task processes inherit it on next launch.
    tacky_cfg_home_win="${dotfiles_unc}\\tacky-borders"
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

    # Register the main task. Action = wscript.exe <UNC launch.vbs>; the VBS
    # does taskkill+wait+launch under Highest so reload is atomic and silent
    # (no console flash, no "already running" dialog).
    tacky_launch_vbs_unc="${dotfiles_unc}\\tacky-borders\\launch.vbs"
    powershell.exe -NoProfile -ExecutionPolicy Bypass \
      -File "$(wslpath -w "$DOTFILES_PATH/tacky-borders/register-task.ps1")" \
      -ExePath "$(wslpath -w "$tacky_exe")" \
      -LaunchVbs "$tacky_launch_vbs_unc" >/dev/null 2>&1
    log_done "tacky-borders scheduled task registered (AtLogOn, Highest) -> $tacky_launch_vbs_unc"

    # Daily theme rotator: AtLogOn + Daily 00:05 calls rotate.ps1 from the UNC
    # dotfiles root directly (no local copy). rotate.ps1 reads/writes via
    # TACKY_BORDERS_CONFIG_HOME, then Start-ScheduledTask's tacky-borders.
    tacky_rotate_unc="${dotfiles_unc}\\tacky-borders\\rotate.ps1"
    powershell.exe -NoProfile -ExecutionPolicy Bypass \
      -File "$(wslpath -w "$DOTFILES_PATH/tacky-borders/register-rotate-task.ps1")" \
      -ScriptPath "$tacky_rotate_unc" >/dev/null 2>&1
    log_done "tacky-borders daily rotator registered (UNC) -> $tacky_rotate_unc"
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
