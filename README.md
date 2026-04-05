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
| **Terminal** | `wezterm` &mdash; workspace switcher, session resurrect, AI tools menu |
| **Editor** | `neovim` (AstroNvim) &middot; `ideavim` |
| **Window Manager** | `aerospace` &mdash; gradient borders, auto-float rules |
| **Keyboard** | `karabiner` &mdash; Right Option &rarr; Hyper, Caps Lock &rarr; Ctrl |
| **Dev** | `git` `lazygit` `fnm` `pnpm` `pyenv` `claude code` |
| **Utility** | `raycast` `wallpaperkiller` |

<details>
<summary><b>Inactive</b> &mdash; configs preserved, not in active use</summary>

| Tool | Note |
|:--|:--|
| `tmux` | Replaced by wezterm |
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

# neovim -- cloned separately via install.sh (astronvim_config)

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
ln -sf ~/.config/.dotfiles/claude/skills ~/.local/share/claude/skills
ln -sf ~/.local/share/claude ~/.claude

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
