# XDG(https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
# export XDG_RUNTIME_DIR="$HOME/Library/Caches/Runtime"

# zsh
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export ZSH="$ZDOTDIR/oh-my-zsh"

# bash_history
export HISTFILE="$XDG_STATE_HOME/bash/history"

# brew (Apple Silicon: /opt/homebrew, Intel: /usr/local)
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"

# use vim as the editor
# VIMINIT은 nvim의 기본 init 로딩을 막으므로, vim 전용 MYVIMRC만 설정
export MYVIMRC="$XDG_CONFIG_HOME/vim/vimrc"
export EDITOR=nvim

# fnm
export FNM_DIR="$XDG_DATA_HOME/fnm"
# npm
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export PNPM_HOME="$XDG_DATA_HOME/pnpm"
export PATH="$PATH:$PNPM_HOME"

# sdkman
export SDKMAN_DIR="$XDG_DATA_HOME/sdkman"

# go
export GOPATH="$XDG_DATA_HOME/go"
export GOMODCACHE="$GOPATH/pkg/mod"
export PATH="$PATH:$GOPATH/bin"


# wget
export WGET_HSTS_FILE="$XDG_CACHE_HOME/wget/wget-hsts"

# fzf
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --info=inline"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'

# pyenv (XDG: 데이터는 $XDG_DATA_HOME 아래로)
export PYENV_ROOT="$XDG_DATA_HOME/pyenv"
export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"

# nvim
export PATH="/opt/nvim/bin:$PATH"

# pipx
export PATH="$PATH:$HOME/.local/bin"

# claude code
export CLAUDE_CONFIG_DIR="$XDG_DATA_HOME/claude"

# remove less history
export LESSHISTFILE=-

# vscode
# export VSCODE_EXTENSIONS="$XDG_DATA_HOME"/vscode/extensions
