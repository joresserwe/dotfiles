---
name: skill-dotfiles-manager
description: Manage the user's macOS dotfiles — add, remove, or modify tool configurations across Brewfile, install.sh, zsh configs, and symlinks. Trigger this skill whenever the user mentions dotfiles, brew packages, shell aliases, tool installation/removal, XDG config, or wants to set up/tear down any CLI tool or macOS app in their environment. Also trigger when the user says "add X", "remove X", "install X", "uninstall X" referring to dev tools or shell utilities.
---

# Dotfiles Manager

You are managing a macOS dotfiles system located at `$XDG_CONFIG_HOME/.dotfiles` (`~/.config/.dotfiles/`), version-controlled via GitHub. The goal: a single `install.sh` restores the full environment from a fresh macOS install.

## Architecture

### XDG Base Directories
All paths follow the XDG Base Directory Specification:
```
XDG_CONFIG_HOME = ~/.config
XDG_DATA_HOME   = ~/.local/share
XDG_STATE_HOME  = ~/.local/state
XDG_CACHE_HOME  = ~/.cache
```

### Dotfiles Structure
```
~/.config/.dotfiles/
├── brew/Brewfile          # Declarative package list
├── zsh/.zshenv            # Environment variables (XDG paths, tool env vars)
├── zsh/.zshrc             # Interactive shell init (plugins, completions, tool init)
├── zsh/.aliases           # Command aliases and shell functions
├── zsh/zfunc/             # Autoload functions
├── install.sh             # Idempotent setup script
├── <tool>/                # Per-tool config directories
└── claude/skills/         # Claude Code skills (this file lives here)
```

### Symlink Convention
install.sh uses `create_link()` to symlink dotfiles configs into their XDG-correct locations:
```bash
create_link "$DOTFILES_PATH/<tool>/<config>" "$XDG_CONFIG_HOME/<tool>/<config>"
```

## Adding a Tool

When the user asks to add a tool, follow these steps **in order**. Before writing anything, use context7 and web search to look up the tool's latest configuration options, XDG support status, and recommended setup for macOS.

### 1. Research
- Search for the tool's XDG compliance (does it respect `XDG_CONFIG_HOME` natively?)
- Find the correct Homebrew formula/cask name
- Identify what config files the tool uses and where it expects them
- If the tool doesn't support XDG natively, find environment variables to redirect its config/data/cache paths

### 2. Brewfile (`brew/Brewfile`)
- Add `brew "<formula>"` or `cask "<formula>"` with a comment describing the tool
- Place it in alphabetical position within its section (brew formulae, then casks, then mas)
- Follow existing comment style: `# Description of the tool`

### 3. Environment Variables (`zsh/.zshenv`)
- Add XDG-compliant path variables if the tool needs them
- Pattern: `export TOOL_CONFIG="$XDG_CONFIG_HOME/tool"` or `export TOOL_DATA="$XDG_DATA_HOME/tool"`
- Add to PATH if needed: `export PATH="$XDG_DATA_HOME/tool/bin:$PATH"`
- Group with similar tools and add a comment

### 4. Shell Initialization (`zsh/.zshrc`)
- Add `eval` or `source` commands if the tool requires shell init
- Add oh-my-zsh plugin name if one exists
- Place after existing tool initializations, following the file's ordering convention

### 5. Aliases (`zsh/.aliases`)
- Add useful aliases or wrapper functions
- Follow existing style: section comment + alias definitions
- For tools that replace builtins (like eza→ls, bat→cat), alias the original command

### 6. Config Files
- Create `<tool>/` directory in dotfiles: `~/.config/.dotfiles/<tool>/`
- Write config files there
- Use context7/web search to find recommended config for the tool

### 7. Symlinks (`install.sh`)
- Add `create_link` calls in the "Symbolic Link" section of install.sh
- Pattern: `create_link "$DOTFILES_PATH/<tool>/<config>" "$XDG_CONFIG_HOME/<tool>/<config>"`
- For directory symlinks: use `ln -sf` directly

### 8. Additional install.sh Steps (if needed)
- Post-install commands (plugin managers, initial setup)
- App launch commands at the end of install.sh
- Required directory creation in the directories array

## Removing a Tool

Reverse the addition order — remove from bottom to top:

1. **install.sh**: Remove symlink creation, directory creation, post-install commands, app launch
2. **Config files**: Delete the tool's directory from dotfiles
3. **Aliases**: Remove related aliases/functions from `.aliases`
4. **Shell init**: Remove eval/source/plugin from `.zshrc`
5. **Environment**: Remove env vars from `.zshenv`
6. **Brewfile**: Remove the brew/cask line and its comment from `Brewfile`

After removal, check for orphaned dependencies — if a brew package was only needed by the removed tool, remove it too.

## Modifying a Tool

When updating configuration:
1. Read the current config files first
2. Use context7/web search for the latest options and best practices
3. Edit the config files in the dotfiles directory (the symlinks ensure changes take effect)

## Important Conventions

- **Language**: see Gotchas below
- **Idempotency**: All install.sh additions must be safe to re-run
- **Deprecation**: When replacing a tool, comment out the old config with `# [DEPRECATED] old → new` rather than deleting immediately
- **XDG first**: If a tool doesn't support XDG natively, set env vars in `.zshenv` to force XDG paths. Document the workaround with a comment
- **No secrets**: Never commit credentials, tokens, or .env files to dotfiles
- **Brewfile.lock.json**: Don't manually edit — it's auto-generated by `brew bundle`
- **⚠️ Portability**: Never use absolute paths like `/Users/username` in config files or scripts. Always use environment variables (`$HOME`, `$XDG_CONFIG_HOME`, `$DOTFILES_PATH`) or relative paths so dotfiles work on any Mac without modification

## Gotchas

- All comments and docs in dotfiles must be English (not Korean).
