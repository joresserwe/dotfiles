# The default C.UTF-8 locale decodes UTF-8 but ships no per-character width
# table, so ZLE treats CJK/wide glyphs as 1 cell while the terminal renders 2
# — the cursor desyncs and Hangul appears to shift left/right on arrow keys.
# A real UTF-8 locale carries the width data. en_US.UTF-8 must be generated:
# sudo locale-gen en_US.UTF-8
export LANG="en_US.UTF-8"

# XDG(https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

export DOTFILES_PATH="$XDG_CONFIG_HOME/.dotfiles"

# Nested shells (tmux panes inherit ZDOTDIR) re-source this file via
# $ZDOTDIR/.zshenv; -U dedupes the repeated PATH prepends. Guarded: bash
# (install.sh) also sources this file and has no typeset -U.
[ -n "${ZSH_VERSION:-}" ] && typeset -U path fpath

export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export ZSH="$ZDOTDIR/oh-my-zsh"

# NOTE: HISTFILE is set in .zshrc — macOS /etc/zshrc runs after .zshenv
# and overrides it, so the export must happen later in .zshrc.

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
    # brew's curl/openssl read $HOMEBREW_PREFIX/etc/ca-certificates/cert.pem,
    # which never sees roots added via update-ca-certificates (e.g. a
    # TLS-intercepting corp proxy) — point OpenSSL at the system bundle.
    [ -f /etc/ssl/certs/ca-certificates.crt ] \
      && export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    ;;
esac
[ -x "$HOMEBREW_PREFIX/bin/brew" ] && eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"

# vim (< 9.1.0327) has no XDG support: EXINIT points it at the XDG vimrc.
# Unlike VIMINIT, EXINIT is read only when no vimrc/init is found, so nvim
# (which has init.lua) never sees it.
export MYVIMRC="$XDG_CONFIG_HOME/vim/vimrc"
export EXINIT='source $MYVIMRC'
export EDITOR=nvim

export MISE_DATA_DIR="$XDG_DATA_HOME/mise"
export MISE_CONFIG_DIR="$XDG_CONFIG_HOME/mise"
export MISE_CACHE_DIR="$XDG_CACHE_HOME/mise"

export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export PNPM_HOME="$XDG_DATA_HOME/pnpm"
# $PNPM_HOME/bin too: pnpm >=10 places the global bin dir there. Prepend so
# WSL-native binaries beat Windows interop copies under /mnt/c (see the
# ~/.local/bin note below).
export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"

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

export WGET_HSTS_FILE="$XDG_CACHE_HOME/wget/wget-hsts"

export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --info=inline"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'

export PATH="/opt/nvim/bin:$PATH"

# pipx / native tool installs (claude, win32yank, xdg-open shim, ...)
# PREPEND, don't append: on WSL the inherited PATH already contains the
# Windows interop dirs (/mnt/c/...), and appending lets a Windows-side
# claude/node shadow the WSL-native ones — slow 9P round-trips for every
# file op. ~/.local/bin must win inside WSL.
export PATH="$HOME/.local/bin:$PATH"

export CLAUDE_CONFIG_DIR="$XDG_DATA_HOME/claude"

# codex — ignores XDG, defaults to ~/.codex unless CODEX_HOME is set
export CODEX_HOME="$XDG_DATA_HOME/codex"

# remove less history
export LESSHISTFILE=-

# vscode
# export VSCODE_EXTENSIONS="$XDG_DATA_HOME"/vscode/extensions
