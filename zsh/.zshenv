# XDG(https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_RUNTIME_DIR="$HOME/Library/Caches/Runtime"

# zsh
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export ZSH="$ZDOTDIR/oh-my-zsh"

# brew
eval "$(/opt/homebrew/bin/brew shellenv)"

# use vim as the editor
export EDITOR=nvim

# nvm
export NVM_DIR="$XDG_DATA_HOME/nvm"

# sdkman
export SDKMAN_DIR="$XDG_DATA_HOME/sdkman"

# go
export GOPATH="$XDG_DATA_HOME/go"
export GOMODCACHE="$GOPATH/pkg/mod"
export PATH="$PATH:$GOPATH/bin"

# npm
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"

# remove less history
export LESSHISTFILE=-

# vscode
# export VSCODE_EXTENSIONS="$XDG_DATA_HOME"/vscode/extensions

# fasd
export _FASD_DATA="$XDG_CACHE_HOME/fasd/fasd"
export _FASD_VIMINFO="$XDG_CACHE_HOME/fasd/viminfo"
