#!/bin/zsh
# install.sh — macOS installer for the dotfiles repo.
# Counterpart to install.linux.sh (WSL/Ubuntu). Idempotent — safe to re-run;
# a re-run pulls the repo and re-applies whatever changed.

export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$HOME/Library/Caches/Runtime}"

DOTFILES_PATH="$XDG_CONFIG_HOME/.dotfiles"

# -----------------------------------------------------------------------------------------------

echo "Installing Homebrew..."
# Apple Silicon: /opt/homebrew, Intel: /usr/local
if [[ "$(uname -m)" == "arm64" ]]; then
	brew_path=/opt/homebrew/bin
else
	brew_path=/usr/local/bin
fi
if [[ ":$PATH:" != *":$brew_path:"* ]]; then
	export PATH="$PATH:$brew_path"
fi
if command -v brew >/dev/null 2>&1; then
	echo "Homebrew already installed."
else
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
brew analytics off

# -----------------------------------------------------------------------------------------------

echo "dotfiles clone / update..."
command -v git >/dev/null 2>&1 || brew install git
if [ -d "$DOTFILES_PATH/.git" ]; then
	before_head="$(git -C "$DOTFILES_PATH" rev-parse HEAD 2>/dev/null)"
	git -C "$DOTFILES_PATH" pull --ff-only || echo "dotfiles pull skipped (offline/dirty/diverged)"
	after_head="$(git -C "$DOTFILES_PATH" rev-parse HEAD 2>/dev/null)"
	# Re-exec once when HEAD moved: zsh reads scripts incrementally, so if the
	# pull rewrote this file mid-run, execution would continue from mismatched
	# byte offsets in the new content.
	if [ "$before_head" != "$after_head" ] && [ -z "${DOTFILES_REEXEC:-}" ]; then
		echo "dotfiles updated — re-executing installer..."
		DOTFILES_REEXEC=1 exec zsh "$DOTFILES_PATH/install.sh"
	fi
else
	mkdir -p "$XDG_CONFIG_HOME"
	git clone https://github.com/joresserwe/dotfiles "$DOTFILES_PATH"
fi

source "$DOTFILES_PATH/lib/common.sh"

# -----------------------------------------------------------------------------------------------

echo "Creating required directories..."
ensure_dir \
	"$XDG_CACHE_HOME" \
	"$XDG_CONFIG_HOME" \
	"$XDG_CONFIG_HOME/karabiner" \
	"$XDG_CONFIG_HOME/npm" \
	"$XDG_CONFIG_HOME/vim" \
	"$XDG_STATE_HOME/vim" \
	"$XDG_STATE_HOME/node" \
	"$XDG_STATE_HOME/python" \
	"$XDG_DATA_HOME" \
	"$XDG_STATE_HOME" \
	"$XDG_RUNTIME_DIR" \
	"$XDG_STATE_HOME/atuin/logs" \
	"$XDG_STATE_HOME/zsh"
chmod 700 "$XDG_RUNTIME_DIR" # XDG basedir spec requires mode 700 on the runtime dir

# -----------------------------------------------------------------------------------------------

echo "Applying XDG environment variables..."
source "$DOTFILES_PATH/zsh/.zshenv"

# -----------------------------------------------------------------------------------------------

echo "brew install..."
brew bundle install --verbose --file "$DOTFILES_PATH/brew/Brewfile"
brew bundle cleanup --file "$DOTFILES_PATH/brew/Brewfile" </dev/null || true

# -----------------------------------------------------------------------------------------------

echo "Installing node / java (via mise)..."
eval "$(mise activate zsh)"
mise use -g node@lts
mise use -g java@temurin-21
# mise activate hooks fire on prompt; in a non-interactive run we must add shims to PATH manually
export PATH="$XDG_DATA_HOME/mise/shims:$PATH"

export PNPM_HOME="${PNPM_HOME:-$XDG_DATA_HOME/pnpm}"
# $PNPM_HOME/bin too: pnpm >=10 places the global bin dir there and refuses
# `install -g` when it's not in PATH.
export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"

for package in yarn npm-check-updates mcp-hub; do
	if pnpm list -g --depth=0 2>/dev/null | grep "$package" >/dev/null; then
		echo "$package is already installed."
	else
		echo "Installing $package..."
		# </dev/null: pnpm >=10 blocks on an interactive build-approval picker
		# when a TTY is attached (see install.linux.sh Phase 3).
		CI=1 pnpm install -g "$package" </dev/null
	fi
done

# -----------------------------------------------------------------------------------------------

echo "Configuring karabiner..."
# copied (not symlinked) — the app overwrites symlinks on save.
cp "$DOTFILES_PATH/karabiner/karabiner.json" "$XDG_CONFIG_HOME/karabiner/karabiner.json"

# -----------------------------------------------------------------------------------------------

echo "Installing oh-my-zsh / powerlevel10k..."
if [ ! -d "$XDG_CONFIG_HOME/zsh/oh-my-zsh" ]; then
	# CHSH=no: macOS default shell is already zsh, and without it the installer
	# can block on an interactive [Y/n] prompt in non-interactive runs.
	ZSH="$XDG_CONFIG_HOME/zsh/oh-my-zsh" RUNZSH="no" KEEP_ZSHRC="yes" CHSH="no" \
		sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
	update_repo "$XDG_CONFIG_HOME/zsh/oh-my-zsh"
fi
create_link "$DOTFILES_PATH/zsh/.p10k.zsh" "$XDG_CONFIG_HOME/zsh/.p10k.zsh"

P10K_DIR="$XDG_CONFIG_HOME/zsh/oh-my-zsh/custom/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
	git clone --depth=1 https://github.com/joresserwe/powerlevel10k.git "$P10K_DIR"
else
	update_repo "$P10K_DIR"
fi
ZSH_AUTOSUG_DIR="$XDG_CONFIG_HOME/zsh/oh-my-zsh/custom/plugins/zsh-autosuggestions"
if [ ! -d "$ZSH_AUTOSUG_DIR" ]; then
	git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUG_DIR"
else
	update_repo "$ZSH_AUTOSUG_DIR"
fi

# -----------------------------------------------------------------------------------------------

echo "Installing nvim config..."
NVIM_DIR="$XDG_CONFIG_HOME/nvim"
NVIM_REPO="https://github.com/joresserwe/nvim-config"
NVIM_REPO_OLD="https://github.com/joresserwe/astronvim_config"

if [ -d "$NVIM_DIR/.git" ]; then
	NVIM_REMOTE="$(git -C "$NVIM_DIR" config --get remote.origin.url 2>/dev/null || echo)"
	if [ "$NVIM_REMOTE" = "$NVIM_REPO" ] || [ "$NVIM_REMOTE" = "${NVIM_REPO}.git" ]; then
		update_repo "$NVIM_DIR"
	elif [ "$NVIM_REMOTE" = "$NVIM_REPO_OLD" ] || [ "$NVIM_REMOTE" = "${NVIM_REPO_OLD}.git" ]; then
		git -C "$NVIM_DIR" remote set-url origin "$NVIM_REPO"
		update_repo "$NVIM_DIR"
	else
		mv "$NVIM_DIR" "${NVIM_DIR}_backup_$(date +%s)"
		git clone "$NVIM_REPO" "$NVIM_DIR"
	fi
elif [ -d "$NVIM_DIR" ]; then
	mv "$NVIM_DIR" "${NVIM_DIR}_backup_$(date +%s)"
	git clone "$NVIM_REPO" "$NVIM_DIR"
else
	git clone "$NVIM_REPO" "$NVIM_DIR"
fi

# -----------------------------------------------------------------------------------------------

echo "Applying macOS defaults..."
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2
defaults write -g "com.apple.swipescrolldirection" -int 0
defaults write -g "com.apple.trackpad.scaling" -int 2

defaults write com.apple.Accessibility ReduceMotionEnabled -int 1

defaults write com.apple.dock autohide -int 1
defaults write com.apple.dock mineffect -string "scale"
defaults write com.apple.dock "minimize-to-application" -int 1
defaults write com.apple.dock "mode-count" -int 36
defaults write com.apple.dock "mru-spaces" -int 0
defaults write com.apple.dock "show-recents" -int 1
defaults write com.apple.dock "wvous-br-corner" -int 4
defaults write com.apple.dock "wvous-br-modifier" -int 0
defaults write com.apple.dock "showAppExposeGestureEnabled" -int 1

defaults write com.apple.desktopservices DSDontWriteNetworkStores true

defaults write com.apple.finder AppleShowAllFiles -bool true

defaults write com.dwarvesv.minimalbar isAutoStart -int 1
defaults write com.dwarvesv.minimalbar isShowPreferences -int 0
defaults write com.dwarvesv.minimalbar numberOfSecondForAutoHide -int 30

defaults write com.pilotmoon.scroll-reverser InvertScrollingOn -int 1

# -----------------------------------------------------------------------------------------------

echo "Linking config files..."

# zsh
create_link "$DOTFILES_PATH/zsh/.zshenv" ~/.zshenv
create_link "$DOTFILES_PATH/zsh/.zshrc" "$XDG_CONFIG_HOME/zsh/.zshrc"
create_link "$DOTFILES_PATH/zsh/.aliases" "$XDG_CONFIG_HOME/zsh/.aliases"
if [ -L "$XDG_CONFIG_HOME/zsh/zfunc" ] && [ ! -e "$XDG_CONFIG_HOME/zsh/zfunc" ]; then
	rm "$XDG_CONFIG_HOME/zsh/zfunc"
fi
# ideavim
create_link "$DOTFILES_PATH/ideavim/mac/.ideavimrc" "$XDG_CONFIG_HOME/ideavim/ideavimrc"
create_link "$DOTFILES_PATH/vim/vimrc" "$XDG_CONFIG_HOME/vim/vimrc"
# git
create_link "$DOTFILES_PATH/git/config" "$XDG_CONFIG_HOME/git/config"
# npm
create_link "$DOTFILES_PATH/npm/npmrc" "$XDG_CONFIG_HOME/npm/npmrc"
# aerospace
create_link "$DOTFILES_PATH/aerospace/aerospace.toml" "$XDG_CONFIG_HOME/aerospace/aerospace.toml"
# yazi
create_link "$DOTFILES_PATH/yazi/yazi.toml" "$XDG_CONFIG_HOME/yazi/yazi.toml"
create_link "$DOTFILES_PATH/yazi/theme.toml" "$XDG_CONFIG_HOME/yazi/theme.toml"
create_link "$DOTFILES_PATH/yazi/keymap.toml" "$XDG_CONFIG_HOME/yazi/keymap.toml"
create_link "$DOTFILES_PATH/yazi/init.lua" "$XDG_CONFIG_HOME/yazi/init.lua"
create_link "$DOTFILES_PATH/yazi/plugins/svg-code.yazi/main.lua" "$XDG_CONFIG_HOME/yazi/plugins/svg-code.yazi/main.lua"
create_link "$DOTFILES_PATH/yazi/plugins/win-paste.yazi/main.lua" "$XDG_CONFIG_HOME/yazi/plugins/win-paste.yazi/main.lua"
create_link "$DOTFILES_PATH/yazi/plugins/win-paste.yazi/paste.ps1" "$XDG_CONFIG_HOME/yazi/plugins/win-paste.yazi/paste.ps1"
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
	h-hg/yamb \
	yazi-rs/flavors:catppuccin-mocha; do
	ya pkg add "$pkg" || true # already-installed exits nonzero; keep going
done
# atuin
create_link "$DOTFILES_PATH/atuin/config.toml" "$XDG_CONFIG_HOME/atuin/config.toml"
# mise
create_link "$DOTFILES_PATH/mise/config.toml" "$XDG_CONFIG_HOME/mise/config.toml"
# wezterm
create_link "$DOTFILES_PATH/wezterm/wezterm.lua" "$XDG_CONFIG_HOME/wezterm/wezterm.lua"
create_link "$DOTFILES_PATH/wezterm/smart-split" "$XDG_CONFIG_HOME/wezterm/smart-split"
ensure_dir "$HOME/.local/bin"
create_link "$DOTFILES_PATH/bin/term-spawn" "$HOME/.local/bin/term-spawn"

# -----------------------------------------------------------------------------------------------

echo "Configuring Claude Code..."
ensure_dir "$XDG_DATA_HOME/claude"
create_link "$DOTFILES_PATH/claude/settings.json" "$XDG_DATA_HOME/claude/settings.json"
git -C "$DOTFILES_PATH" config filter.strip-claude-model.clean 'jq --indent 2 "del(.model)"'
create_link "$DOTFILES_PATH/claude/CLAUDE.md" "$XDG_DATA_HOME/claude/CLAUDE.md"
if [ -L "$XDG_DATA_HOME/claude/skills" ] || [ ! -e "$XDG_DATA_HOME/claude/skills" ]; then
	ln -sfn "$DOTFILES_PATH/claude/skills" "$XDG_DATA_HOME/claude/skills"
fi
# Legacy (pre-2026-07): ~/.claude was a symlink to $XDG_DATA_HOME/claude —
# through it the create_link below would clobber the XDG settings.json.
# CLAUDE_CONFIG_DIR (.zshenv) made the link obsolete; see install.linux.sh Phase 5.
if [ -L "$HOME/.claude" ]; then
	rm "$HOME/.claude"
fi
create_link "$DOTFILES_PATH/claude/settings.home.json" "$HOME/.claude/settings.json"

# Claude Code CLI — native installer (~/.local/bin/claude), self-updates afterwards.
if command -v claude >/dev/null 2>&1 || [ -x "$HOME/.local/bin/claude" ]; then
	echo "claude CLI already installed."
else
	curl -fsSL https://claude.ai/install.sh | bash
fi

# -----------------------------------------------------------------------------------------------

echo "Sourcing zshrc..."
source "$XDG_CONFIG_HOME/zsh/.zshrc"
# -----------------------------------------------------------------------------------------------

echo "Setting default browser..."
open -a "Google Chrome" --args --make-default-browser

open -a Karabiner-Elements
open -a JetBrains\ Toolbox
open -a AltTab
open -a Google\ Chrome
open -a Raycast
open -a Scroll\ Reverser
open -a Hidden\ Bar
open -a RunCat
open -a CleanMyMac

echo ""
echo "[manual] Surfingkeys — once per browser: in the extension settings, set 'Load settings from' to:"
echo "  https://raw.githubusercontent.com/joresserwe/dotfiles/master/surfingkeys/config.js"
