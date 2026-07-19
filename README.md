<h1 align="center">~/.dotfiles</h1>

<p align="center">
  <em>Personal dev environment &mdash; XDG compliant, single-command bootstrap</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Shell-Zsh-informational?logo=gnubash&logoColor=white" alt="Zsh">
  <img src="https://img.shields.io/badge/Editor-Neovim-green?logo=neovim&logoColor=white" alt="Neovim">
  <img src="https://img.shields.io/badge/Theme-Catppuccin%20Mocha-mauve?logo=catppuccin&logoColor=white" alt="Catppuccin Mocha">
</p>

---

## Stack

> Tools I actively use day-to-day.

| Category | Tools |
|:--|:--|
| **Shell** | `zsh` `oh-my-zsh` `powerlevel10k` `fzf` `ripgrep` `fd` `zoxide` `atuin` `eza` `bat` |
| **Terminal** | macOS: `wezterm` &mdash; workspace switcher, session resurrect, AI tools menu &middot; WinOS: `Windows Terminal` (focus mode) + `tmux` |
| **Editor** | `neovim` (AstroNvim) &middot; `ideavim` |
| **Window Manager** | `aerospace` &mdash; gradient borders, auto-float rules |
| **Keyboard** | `karabiner` &mdash; Right Option &rarr; Hyper, Caps Lock &rarr; Ctrl |
| **Dev** | `git` `lazygit` `fnm` `pnpm` `pyenv` `claude code` |
| **Utility** | `raycast` `wallpaperkiller` |
| **Browser** | `surfingkeys` &mdash; keyboard-driven web surfing, config loaded from raw URL |

<details>
<summary><b>Inactive</b> &mdash; configs preserved, not in active use</summary>

| Tool | Note |
|:--|:--|
| `yazi` | File manager, not currently used |
| `yabai` / `skhd` | Replaced by aerospace |

</details>

## Highlights

- **One-command bootstrap** &mdash; `install.sh` handles Homebrew, packages, symlinks, and macOS defaults
- **ARM64 / Intel** auto-detection for Homebrew paths
- **Fuzzy finders everywhere** &mdash; `ff` files &middot; `f/` grep &middot; `fz` dirs &middot; `fh` history &middot; `fa` aliases
- **Wezterm AI menu** &mdash; Claude Code, Codex, Gemini CLI via `C-a + A`
- **Catppuccin Mocha** unified across terminal, editor, and tools

## Setup

```bash
curl -fsSL https://raw.githubusercontent.com/joresserwe/dotfiles/master/install.sh | zsh
```

The script will:

1. Create XDG directories
2. Install Homebrew & all packages from `Brewfile`
3. Set up Node.js (fnm + pnpm global packages)
4. Clone oh-my-zsh, powerlevel10k, AstroNvim
5. Apply symlinks & macOS defaults

<details>
<summary>Symlink reference</summary>

```bash
# zsh
ln -sf ~/.config/.dotfiles/zsh/.zshenv ~/.zshenv
ln -sf ~/.config/.dotfiles/zsh/.zshrc ~/.config/zsh/.zshrc
ln -sf ~/.config/.dotfiles/zsh/.aliases ~/.config/zsh/.aliases

# neovim -- cloned separately via install.sh (nvim-config)

# ideavim
ln -sf ~/.config/.dotfiles/ideavim/mac/.ideavimrc ~/.config/ideavim/ideavimrc

# git
ln -sf ~/.config/.dotfiles/git/config ~/.config/git/config

# wezterm
ln -sf ~/.config/.dotfiles/wezterm/wezterm.lua ~/.config/wezterm/wezterm.lua

# aerospace
ln -sf ~/.config/.dotfiles/aerospace/aerospace.toml ~/.config/aerospace/aerospace.toml

# karabiner -- copied (not symlinked) by install.sh

# atuin
ln -sf ~/.config/.dotfiles/atuin/config.toml ~/.config/atuin/config.toml

# claude code
ln -sf ~/.config/.dotfiles/claude/settings.json ~/.local/share/claude/settings.json
ln -sf ~/.config/.dotfiles/claude/CLAUDE.md ~/.local/share/claude/CLAUDE.md
ln -sf ~/.config/.dotfiles/claude/skills ~/.local/share/claude/skills

# tmux (inactive)
ln -sf ~/.config/.dotfiles/tmux/tmux.conf ~/.config/tmux/tmux.conf
ln -sf ~/.config/.dotfiles/tmux/tmux.mapping.conf ~/.config/tmux/tmux.mapping.conf
ln -sf ~/.config/.dotfiles/tmux/gitmux.conf ~/.config/tmux/gitmux.conf

# yazi (inactive)
ln -sf ~/.config/.dotfiles/yazi/yazi.toml ~/.config/yazi/yazi.toml
ln -sf ~/.config/.dotfiles/yazi/theme.toml ~/.config/yazi/theme.toml
ln -sf ~/.config/.dotfiles/yazi/keymap.toml ~/.config/yazi/keymap.toml
```

</details>

## Notes

- **Aerospace** requires no SIP modification, unlike yabai which needs [partial SIP disable](https://github.com/koekeishiya/yabai/wiki/Installing-yabai-(latest-release)).
- **Karabiner** config is _copied_ (not symlinked) because the app overwrites symlinks on save.
- **Surfingkeys** is a browser extension, so its config lives in the repo but isn't symlinked. In the extension's settings page, set **"Load settings from"** to the raw config URL — one field to paste per new browser, then `git push` propagates to every machine:

  ```
  https://raw.githubusercontent.com/joresserwe/dotfiles/master/surfingkeys/config.js
  ```

  Offline alternative: point it at a local `file://` absolute path instead (Windows browser reads the mirror, e.g. `file:///C:/Users/<you>/.dotfiles/surfingkeys/config.js`).

## WSL2 / Ubuntu

For Windows users running WSL2 Ubuntu, use `install.linux.sh` instead of `install.sh`:

```bash
git clone https://github.com/joresserwe/dotfiles ~/.config/.dotfiles
~/.config/.dotfiles/install.linux.sh
```

Optional profile flags: `--full` (default; Raycast, full zebar effects) or `--light` (Flow Launcher, reduced zebar effects — for GPU-less VMs/RDP hosts). The choice is persisted in `$XDG_STATE_HOME/dotfiles/profile` and reused on flagless re-runs.

The Linux installer reproduces the macOS CLI environment (zsh + oh-my-zsh + powerlevel10k, neovim/AstroNvim, tmux, yazi, atuin, mise, claude code) using a hybrid **apt + Homebrew on Linux** setup. macOS-only tools (aerospace, karabiner, raycast, wallpaperkiller, casks, mas) are skipped automatically via `if OS.mac?` guards in the shared `Brewfile`.

### Architecture

- Single repo, single source of truth. OS differences are expressed as inline runtime branches (`case $OSTYPE` in shell, `if OS.mac?` in Brewfile) — no `darwin/`/`linux/` split folders.
- `lib/common.sh` is a sourced-only library (mode 644) shared by both `install.sh` and `install.linux.sh`.
- Phased structure (Phases 0–5) — fully idempotent, safe to re-run.
- **Windows-local mirror** — Windows-side consumers (GlazeWM template/helpers, zebar, tacky-borders, winkey.ahk) read from `%USERPROFILE%\.dotfiles` (`DOTFILES_WIN`), never from `\\wsl.localhost` — at logon the WSL VM isn't up, so anything UNC-based dies on cold boot. The mirror is refreshed by `install.linux.sh` and by `winget/sync-windows.ps1` (first step of the Hyper+C reload chain); `DOTFILES_UNC` survives only as the sync source. `tacky-borders/config.yaml` in the mirror is runtime state (theme rotation) and excluded from sync.

### Phases

| Phase | What |
|:--|:--|
| **0** | XDG dirs, apt base packages, Homebrew on Linux |
| **1** | zsh + oh-my-zsh + powerlevel10k + zsh-autosuggestions, `chsh` |
| **2** | `brew bundle` (Linux subset) + tmux/git/atuin/yazi configs |
| **3** | mise + node LTS + global pnpm packages |
| **4** | AstroNvim clone |
| **5** | Claude Code symlinks |

### Windows-side setup

On a fresh PC, run `bootstrap.windows.ps1` once **before** WSL exists (any PowerShell — self-elevates via UAC):

```powershell
irm https://raw.githubusercontent.com/joresserwe/dotfiles/master/bootstrap.windows.ps1 | iex
```

It covers exactly what `install.linux.sh` cannot, since that script runs inside WSL:

1. **WSL platform** — enables the `Microsoft-Windows-Subsystem-Linux` and `VirtualMachinePlatform` features, installs the WSL Store package via winget, and queues the Ubuntu distro. A reboot is required afterwards.
2. **Fonts** — installs the terminal font fallback chain into per-user Windows Fonts (`%LOCALAPPDATA%\Microsoft\Windows\Fonts`), always fetching the latest release:
   - **0xProto Nerd Font** — primary (Latin + Nerd Font glyphs), from [nerd-fonts releases](https://github.com/ryanoasis/nerd-fonts/releases).
   - **Sarasa Mono K** — CJK fallback for Korean, from [be5invis/Sarasa-Gothic releases](https://github.com/be5invis/Sarasa-Gothic/releases). License: SIL OFL-1.1.
   - **codicon** — covers VS Code PUA glyphs emitted by Claude Code's TUI, from [@vscode/codicons](https://unpkg.com/@vscode/codicons/dist/codicon.ttf).

   Idempotent: already-installed families are skipped; pass `-RefreshFonts` to force an update.
3. **Registry tweaks** — runs `winget/registry.ps1` elevated, so the HKLM Scancode Map (CapsLock → Ctrl, LWin → F13) actually lands — an unelevated pass silently cannot write it, and winkey.ahk + the glazewm Hyper chain depend on it.

After the reboot, `wsl --install -d Ubuntu` creates the Linux user; then run `install.linux.sh` from a terminal launched **as Administrator** — the RunLevel=Highest scheduled tasks (glazewm autostart, winkey, tacky-borders) are registered through WSL interop, which inherits the terminal's token.

Still manual:

1. **Default profile** — in Windows Terminal, set the default profile to launch `wsl.exe -d Ubuntu` so new tabs land in zsh.
2. **Clipboard** — works out of the box: tmux uses `set-clipboard on` (OSC 52) and the `_dotfiles_copy` shell helper falls back to `clip.exe` if no Wayland/X clipboard tool is present.
