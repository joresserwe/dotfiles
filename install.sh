#!/bin/zsh

# XDG 변수 기본값 설정 (스크립트 실행 시 XDG 변수가 설정되지 않은 경우를 대비)
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$HOME/Library/Caches/Runtime}"

DOTFILES_PATH="$XDG_CONFIG_HOME/.dotfiles"

# -----------------------------------------------------------------------------------------------

echo "필요 경로 생성..."
directories=(
	"$XDG_CACHE_HOME"
	"$XDG_CONFIG_HOME"
	"$XDG_CONFIG_HOME/karabiner"
	"$XDG_CONFIG_HOME/npm"
	"$XDG_CONFIG_HOME/vim"
	"$XDG_STATE_HOME/vim"
	"$XDG_DATA_HOME"
	"$XDG_STATE_HOME"
	"$XDG_RUNTIME_DIR"
)
for dir in "${directories[@]}"; do
	if [ -d "$dir" ]; then
		echo "Directory already exists: $dir"
	else
		echo "Directory does not exist, creating: $dir"
		mkdir -p "$dir"
	fi
done
chmod 700 "$XDG_RUNTIME_DIR" # XDG에 따르면, runtime의 경로는 700 권한을 줘야한다.

# -----------------------------------------------------------------------------------------------

echo "Homebrew 설치..."
brew_path=/opt/homebrew/bin
if [[ ":$PATH:" != *":$brew_path:"* ]]; then
	export PATH="$PATH:$brew_path"
fi
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew analytics off

# -----------------------------------------------------------------------------------------------

echo "git clone dotfiles..."
brew install git
if [ -d "$DOTFILES_PATH" ]; then
	/bin/rm -rf "$DOTFILES_PATH"
fi
git clone https://github.com/joresserwe/dotfiles "$DOTFILES_PATH"


# -----------------------------------------------------------------------------------------------

echo "XDG 환경변수 설정..."
source "$DOTFILES_PATH/zsh/.zshenv"

# -----------------------------------------------------------------------------------------------

echo "brew install..."
brew bundle install --file "$DOTFILES_PATH/brew/Brewfile"

# -----------------------------------------------------------------------------------------------

echo "node 설치..."
eval "$(fnm env --shell zsh)"
fnm install --lts
packages=(
	"yarn"
	"npm-check-updates"
	"mcp-hub"
)
for package in "${packages[@]}"; do
	if pnpm list -g --depth=0 | grep "$package" >/dev/null; then
		echo "$package is already installed."
	else
		echo "Installing $package..."
		pnpm install -g "$package"
	fi
done


# -----------------------------------------------------------------------------------------------

echo "karabiner 설정..."
cp "$DOTFILES_PATH/karabiner/karabiner.json" "$XDG_CONFIG_HOME/karabiner/karabiner.json"

# -----------------------------------------------------------------------------------------------

echo "oh-my-zsh / powerlevel10k 설치..."
ZSH="$XDG_CONFIG_HOME/zsh/oh-my-zsh" RUNZSH="no" KEEP_ZSHRC="yes" sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
cp "$DOTFILES_PATH/zsh/.p10k.zsh" "$XDG_CONFIG_HOME/zsh/.p10k.zsh"

if [ ! -d "$XDG_CONFIG_HOME/zsh/oh-my-zsh/custom/themes/powerlevel10k" ]; then
	git clone --depth=1 https://github.com/joresserwe/powerlevel10k.git "$XDG_CONFIG_HOME/zsh/oh-my-zsh/custom/themes/powerlevel10k"
fi
if [ ! -d "$XDG_CONFIG_HOME/zsh/oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
	git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$XDG_CONFIG_HOME/zsh/oh-my-zsh/custom/plugins/zsh-autosuggestions"
fi

# -----------------------------------------------------------------------------------------------

echo "astronvim 설치..."
if [ -d "$XDG_CONFIG_HOME/nvim" ]; then
	mv "$XDG_CONFIG_HOME/nvim" "$XDG_CONFIG_HOME/nvim_backup"
fi
git clone https://github.com/joresserwe/astronvim_config "$XDG_CONFIG_HOME/nvim"

# -----------------------------------------------------------------------------------------------

echo "yabai 설정..."
echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 $(which yabai) | cut -d " " -f 1) $(which yabai) --load-sa" | sudo tee /private/etc/sudoers.d/yabai
sudo nvram boot-args=-arm64e_preview_abi

# -----------------------------------------------------------------------------------------------

echo "defaults 설정 변경..."
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

echo "설정파일 Symbolic Lync 연결..."
create_link() {
	local target_file="$1"
	local link_path="$2"
	local link_dir=$(dirname "$link_path")
	if [ ! -d "$link_dir" ]; then
		echo "Directory does not exist, creating: $link_dir"
		mkdir -p "$link_dir"
	fi
	ln -sf "$target_file" "$link_path"
}

# zsh
create_link "$DOTFILES_PATH/zsh/.zshenv" ~/.zshenv
create_link "$DOTFILES_PATH/zsh/.zshrc" "$XDG_CONFIG_HOME/zsh/.zshrc"
create_link "$DOTFILES_PATH/zsh/.aliases" "$XDG_CONFIG_HOME/zsh/.aliases"
ln -sf "$DOTFILES_PATH/zsh/zfunc" "$XDG_CONFIG_HOME/zsh/zfunc"
# ideavim
create_link "$DOTFILES_PATH/ideavim/mac/.ideavimrc" "$XDG_CONFIG_HOME/ideavim/ideavimrc"
# git
create_link "$DOTFILES_PATH/git/config" "$XDG_CONFIG_HOME/git/config"
# tmux
create_link "$DOTFILES_PATH/tmux/tmux.conf" "$XDG_CONFIG_HOME/tmux/tmux.conf"
create_link "$DOTFILES_PATH/tmux/tmux.mapping.conf" "$XDG_CONFIG_HOME/tmux/tmux.mapping.conf"
create_link "$DOTFILES_PATH/tmux/gitmux.conf" "$XDG_CONFIG_HOME/tmux/gitmux.conf"
# yabai
create_link "$DOTFILES_PATH/yabai/skhdrc" "$XDG_CONFIG_HOME/skhd/skhdrc"
create_link "$DOTFILES_PATH/yabai/yabairc" "$XDG_CONFIG_HOME/yabai/yabairc"
# yazi
create_link "$DOTFILES_PATH/yazi/yazi.toml" "$XDG_CONFIG_HOME/yazi/yazi.toml"
create_link "$DOTFILES_PATH/yazi/theme.toml" "$XDG_CONFIG_HOME/yazi/theme.toml"
create_link "$DOTFILES_PATH/yazi/keymap.toml" "$XDG_CONFIG_HOME/yazi/keymap.toml"
# wezterm
create_link "$DOTFILES_PATH/wezterm/wezterm.lua" "$XDG_CONFIG_HOME/wezterm/wezterm.lua"
# claude code
create_link "$DOTFILES_PATH/claude/settings.json" "$XDG_DATA_HOME/claude/settings.json"
ln -sf "$DOTFILES_PATH/claude/skills" "$XDG_DATA_HOME/claude/skills"
ln -sf "$XDG_DATA_HOME/claude" ~/.claude # claude code가 XDG를 완전히 지원하지 않아 ~/.claude를 참조하는 문제 우회

# -----------------------------------------------------------------------------------------------

echo "zshrc 적용..."
source "$XDG_CONFIG_HOME/zsh/.zshrc"
# -----------------------------------------------------------------------------------------------

open -a Karabiner-Elements
open -a JetBrains\ Toolbox
open -a AltTab
open -a Google\ Chrome
open -a Raycast
open -a Scroll\ Reverser
open -a Arc
open -a Hidden\ Bar
open -a RunCat
open -a CheatSheet
open -a CleanMyMac

# open -a "CleanShot X"
# open -a BetterTouchTool
