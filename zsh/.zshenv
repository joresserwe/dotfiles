# XDG(https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# Dotfiles
export DOTFILES_PATH="$XDG_CONFIG_HOME/.dotfiles"

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
# vim (< 9.1.0327) has no XDG support: EXINIT points it at the XDG vimrc.
# Unlike VIMINIT, EXINIT is read only when no vimrc/init is found, so nvim
# (which has init.lua) never sees it.
export MYVIMRC="$XDG_CONFIG_HOME/vim/vimrc"
export EXINIT='source $MYVIMRC'
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

# gradle — ignores XDG, writes to ~/.gradle unless GRADLE_USER_HOME is set
export GRADLE_USER_HOME="$XDG_DATA_HOME/gradle"

# kubectl — ignores XDG, defaults to ~/.kube for config and cache
export KUBECONFIG="$XDG_CONFIG_HOME/kube/config"
export KUBECACHEDIR="$XDG_CACHE_HOME/kube"

# node REPL history — defaults to ~/.node_repl_history; the parent dir must
# already exist or node silently disables history persistence
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node/repl_history"

# python REPL history — honored by CPython >=3.13 (older versions ignore the
# var and fall back to ~/.python_history)
export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"


# wget
export WGET_HSTS_FILE="$XDG_CACHE_HOME/wget/wget-hsts"

# fzf
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --info=inline"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'

# nvim
export PATH="/opt/nvim/bin:$PATH"

# pipx / native tool installs (claude, win32yank, xdg-open shim, ...)
# PREPEND, don't append: on WSL the inherited PATH already contains the
# Windows interop dirs (/mnt/c/...), and appending lets a Windows-side
# claude/node shadow the WSL-native ones — slow 9P round-trips for every
# file op. ~/.local/bin must win inside WSL.
export PATH="$HOME/.local/bin:$PATH"

# claude code
export CLAUDE_CONFIG_DIR="$XDG_DATA_HOME/claude"

# remove less history
export LESSHISTFILE=-

# vscode
# export VSCODE_EXTENSIONS="$XDG_DATA_HOME"/vscode/extensions
