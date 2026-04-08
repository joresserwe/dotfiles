# XDG(https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# zsh
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export ZSH="$ZDOTDIR/oh-my-zsh"

# NOTE: HISTFILE is set in .zshrc — macOS /etc/zshrc runs after .zshenv
# and overrides it, so the export must happen later in .zshrc.

# OS-specific: XDG_RUNTIME_DIR and Homebrew prefix
case "$OSTYPE" in
  darwin*)
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$HOME/Library/Caches/Runtime}"
    if [ -x /opt/homebrew/bin/brew ]; then
      export HOMEBREW_PREFIX="/opt/homebrew"
    else
      export HOMEBREW_PREFIX="/usr/local"
    fi
    ;;
  linux*)
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
    export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
    ;;
esac
[ -x "$HOMEBREW_PREFIX/bin/brew" ] && eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"

# use vim as the editor
# VIMINIT은 nvim의 기본 init 로딩을 막으므로, vim 전용 MYVIMRC만 설정
export MYVIMRC="$XDG_CONFIG_HOME/vim/vimrc"
export EDITOR=nvim

# mise (replaces fnm + pyenv; manages node, python, go, ruby, etc.)
export MISE_DATA_DIR="$XDG_DATA_HOME/mise"
export MISE_CONFIG_DIR="$XDG_CONFIG_HOME/mise"
export MISE_CACHE_DIR="$XDG_CACHE_HOME/mise"

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
