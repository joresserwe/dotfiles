# p10k instant prompt (must be at the very top)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  . "${XDG_CACHE_HOME:-$HOME/.cache}/p10k/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Restore XDG-compliant HISTFILE (macOS /etc/zshrc overrides .zshenv)
export HISTFILE="$XDG_STATE_HOME/zsh/history"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
	git
	fzf
	zsh-autosuggestions
	# tmux

	sprunge
	sdk
)

# User-generated completions (install.linux.sh writes trash-cli's here).
# Must be on fpath BEFORE oh-my-zsh runs compinit.
[ -d "$XDG_DATA_HOME/zsh/site-functions" ] && fpath=("$XDG_DATA_HOME/zsh/site-functions" $fpath)

[ -f "$ZSH/oh-my-zsh.sh" ] && . "$ZSH/oh-my-zsh.sh"
[ -f "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && . "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# p10k
[ -f "$ZDOTDIR/.p10k.zsh" ] && . "$ZDOTDIR/.p10k.zsh"

# brew completions (compinit already handled by oh-my-zsh; must run before carapace)
if [[ -d "$HOMEBREW_PREFIX/share/zsh/site-functions" ]]; then
  FPATH="$HOMEBREW_PREFIX/share/zsh/site-functions:${FPATH}"
fi

# Case-insensitive completion (including first char). Also allow partial-word
# matching on separators and left/right partial matches.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# carapace: unified multi-shell completion for 600+ CLIs (must be after compinit)
if command -v carapace &>/dev/null; then
  export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
  export CARAPACE_MATCH=CASE_INSENSITIVE
  local _carapace_cache="$XDG_CACHE_HOME/carapace/init.zsh"
  if [[ ! -f "$_carapace_cache" || "$(command -v carapace)" -nt "$_carapace_cache" ]]; then
    mkdir -p "${_carapace_cache:h}"
    carapace _carapace zsh > "$_carapace_cache"
  fi
  source "$_carapace_cache"
fi

# mise (replaces fnm + pyenv)
# eval "$(mise activate zsh)"
export PATH="$HOME/.local/share/mise/shims:$PATH"

# zoxide
eval "$(zoxide init zsh)"

# atuin
eval "$(atuin init zsh --disable-ctrl-r --disable-up-arrow)"

# K8S
# . <(kubectl completion zsh)
# . ~/.minikube/.minikube-completion
# export KUBE_EDITOR="nvim"

# sdkman
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && . "$HOME/.config/envman/load.sh"


# BindKey
# zle (Z-shell Line Editor)를 등록한 후, 단축키를 Binding 한다.
# zle -N src
# bindkey '^e' src # ^e를 누르면 src 명령어가 나간다.

# aliases
[ -f "$XDG_CONFIG_HOME/zsh/.aliases" ] && . "$XDG_CONFIG_HOME/zsh/.aliases"

# wezterm shell integration (OSC 7/133/1337: cwd tracking, prompt zones, user vars)
if [[ -f "$DOTFILES_PATH/wezterm/wezterm.sh" ]] \
  && [[ "${TERM_PROGRAM:-}" == "WezTerm" ]]; then
  . "$DOTFILES_PATH/wezterm/wezterm.sh"

  # Feed the wezterm status bar git segment: gitmux state as a pane user var,
  # refreshed on every prompt (~13ms). Empty outside a repo hides the segment.
  # Not __wezterm_set_user_var: GNU base64 wraps at 76 cols, and the embedded
  # newlines corrupt the OSC sequence for values this long.
  __wezterm_git_status_precmd() {
    local json b64
    json="$(command gitmux -dbg -timeout 500ms "$PWD" 2>/dev/null)" || json=""
    b64="$(printf %s "$json" | base64 | tr -d '\n')"
    if [[ -z "${TMUX-}" ]]; then
      printf "\033]1337;SetUserVar=%s=%s\007" "git_status" "$b64"
    else
      printf "\033Ptmux;\033\033]1337;SetUserVar=%s=%s\007\033\\" "git_status" "$b64"
    fi
  }
  precmd_functions+=(__wezterm_git_status_precmd)
fi

#neofetch

