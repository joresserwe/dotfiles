# zsh
export ZDOTDIR="$HOME/.config/zsh"
export ZSH="$ZDOTDIR/oh-my-zsh"

# set xdg paths
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# PATH
export PATH="$HOME/.local/bin:$PATH"

# brew
eval "$(/opt/homebrew/bin/brew shellenv)"

# use vim as the editor
export EDITOR=nvim

# nvim
export NVM_DIR="$XDG_DATA_HOME/nvm"

# sdkman
export SDKMAN_DIR="$XDG_DATA_HOME/sdkman"

# go
export GOPATH="$XDG_DATA_HOME/go"
export GOMODCACHE="$GOPATH/pkg/mod"
export PATH="$PATH:$GOPATH/bin"

# nvm
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/.npmrc"

