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

[ -f "$ZSH/oh-my-zsh.sh" ] && . "$ZSH/oh-my-zsh.sh"
[ -f "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && . "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
# zsh-vi-mode: vim keybindings in the shell
[ -f "$HOMEBREW_PREFIX/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh" ] && . "$HOMEBREW_PREFIX/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh"

# p10k
[ -f "$ZDOTDIR/.p10k.zsh" ] && . "$ZDOTDIR/.p10k.zsh"

# brew completions + compinit (must run before carapace)
if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"

  autoload -Uz compinit
  compinit
fi

# carapace: unified multi-shell completion for 600+ CLIs (must be after compinit)
if command -v carapace &>/dev/null; then
  export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
  zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
  source <(carapace _carapace zsh)
fi

# mise (replaces fnm + pyenv)
eval "$(mise activate zsh)"

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

#neofetch

