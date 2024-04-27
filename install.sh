#!/bin/zsh
config_dir="$HOME/.config"
dotfiles_dir="$config_dir/.dotfiles"

# -----------------------------------------------------------------------------------------------

echo "필요 경로 생성..."
directories=(
	"$HOME/.cache"
	"$HOME/.config"
	"$HOME/.config/karabiner"
	"$HOME/.config/npm"
	"$HOME/.local/share"
	"$HOME/.local/state"
	"$HOME/Library/Caches/Runtime"
)
for dir in "${directories[@]}"; do
	if [ -d "$dir" ]; then
		echo "Directory already exists: $dir"
	else
		echo "Directory does not exist, creating: $dir"
		mkdir -p "$dir"
	fi
done
chmod 700 $HOME/Library/Caches/Runtime # XDG에 따르면, runtime의 경로는 700 권한을 줘야한다.

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
if [ -d "$dotfiles_dir" ]; then
	/bin/rm -rf "$dotfiles_dir"
fi
git clone https://github.com/joresserwe/dotfiles $dotfiles_dir

# -----------------------------------------------------------------------------------------------

echo "XDG 환경변수 설정..."
source $dotfiles_dir/zsh/.zshenv

# -----------------------------------------------------------------------------------------------

echo "brew install..."
brew bundle install --file $dotfiles_dir/brew/Brewfile

# -----------------------------------------------------------------------------------------------

echo "node 설치..."
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
nvm install --lts
npm config set cache $config_dir/npm/npmrc --global
packages=(
	"yarn"
	"npm-check-updates"
	"stylelint"
)
for package in "${packages[@]}"; do
	if npm list -g --depth=0 | grep "$package" >/dev/null; then
		echo "$package is already installed."
	else
		echo "Installing $package..."
		npm install -g "$package"
	fi
done

# -----------------------------------------------------------------------------------------------

echo "karabiner 설정..."
cp $dotfiles_dir/karabiner/karabiner.json $config_dir/karabiner/karabiner.json

# -----------------------------------------------------------------------------------------------

echo "oh-my-zsh / powerlevel10k 설치..."
ZSH="$config_dir/zsh/oh-my-zsh" RUNZSH="no" KEEP_ZSHRC="yes" sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
cp $dotfiles_dir/zsh/.p10k.zsh $config_dir/zsh/.p10k.zsh

if [ ! -d "$config_dir/zsh/oh-my-zsh/custom/themes/powerlevel10k" ]; then
	git clone --depth=1 https://github.com/joresserwe/powerlevel10k.git $config_dir/zsh/oh-my-zsh/custom/themes/powerlevel10k
fi
if [ ! -d "$config_dir/zsh/oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
	git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions $config_dir/zsh/oh-my-zsh/custom/plugins/zsh-autosuggestions
fi

# -----------------------------------------------------------------------------------------------
 
echo "fasd 실행..."
if [ -f "/usr/local/bin/fasd" ]; then
	echo "fasd is already installed"
else 
	fasd_path="$HOME/.local/share/fasd"
	git clone https://github.com/clvv/fasd.git $fasd_path
	cd $fasd_path
	sudo make install
	cd ~
	/bin/rm -rf $fasd_path
fi
 
# -----------------------------------------------------------------------------------------------

echo "astronvim 설치..."
if [ -d "$config_dir/nvim" ]; then
	mv $config_dir/nvim $config_dir/nvim_backup
fi
git clone https://github.com/joresserwe/astronvim_config $config_dir/nvim

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

defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$dotfiles_dir/iterm2"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

defaults write com.dwarvesv.minimalbar isAutoStart -int 1
defaults write com.dwarvesv.minimalbar isShowPreferences -int 0
defaults write com.dwarvesv.minimalbar numberOfSecondForAutoHide -int 30

defaults write com.pilotmoon.scroll-reverser InvertScrollingOn = 1

 -----------------------------------------------------------------------------------------------

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
create_link $dotfiles_dir/zsh/.zshenv ~/.zshenv
create_link $dotfiles_dir/zsh/.zshrc $config_dir/zsh/.zshrc
create_link $dotfiles_dir/zsh/.aliases $config_dir/zsh/.aliases
ln -sf $dotfiles_dir/zsh/zfunc $config_dir/zsh/zfunc
# ideavim
create_link $dotfiles_dir/ideavim/mac/.ideavimrc $config_dir/ideavim/ideavimrc
# git
create_link $dotfiles_dir/git/config $config_dir/git/config
# tmux
create_link $dotfiles_dir/tmux/tmux.conf $config_dir/tmux/tmux.conf
create_link $dotfiles_dir/tmux/tmux.mapping.conf $config_dir/tmux/tmux.mapping.conf
create_link $dotfiles_dir/tmux/gitmux.conf $config_dir/tmux/gitmux.conf
# yabai
create_link $dotfiles_dir/yabai/skhdrc $config_dir/skhd/skhdrc
create_link $dotfiles_dir/yabai/yabairc $config_dir/yabai/yabairc
# yazi
create_link $dotfiles_dir/yazi/yazi.toml $config_dir/yazi/yazi.toml
create_link $dotfiles_dir/yazi/theme.toml $config_dir/yazi/theme.toml
create_link $dotfiles_dir/yazi/keymap.toml $config_dir/yazi/keymap.toml

# -----------------------------------------------------------------------------------------------

echo "zshrc 적용..."
source $config_dir/zsh/.zshrc

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
open -a "CleanMyMac X"

# open -a "CleanShot X"
# open -a BetterTouchTool
