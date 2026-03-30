# p10k instant prompt (must be at the very top)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  . "${XDG_CACHE_HOME:-$HOME/.cache}/p10k/p10k-instant-prompt-${(%):-%n}.zsh"
fi

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
[ -f "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && . "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# p10k
[ -f "$ZDOTDIR/.p10k.zsh" ] && . "$ZDOTDIR/.p10k.zsh"

# brew
if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"

  autoload -Uz compinit
  compinit
fi

# pyenv
eval "$(pyenv init -)"

# fnm
eval "$(fnm env --use-on-cd --shell zsh)"

# zoxide
eval "$(zoxide init zsh)"

# K8S
# . <(kubectl completion zsh)
# . ~/.minikube/.minikube-completion
# export KUBE_EDITOR="nvim"

# sdkman
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && . "$HOME/.config/envman/load.sh"

# Auto Function
# 함수로 추가할 디렉토리를 auto complete 목록에 포함합니다.
# autoload에 zfunc이하 모든 항목을 선언합니다.
fpath=($fpath $ZDOTDIR/zfunc)
autoload -Uz $ZDOTDIR/zfunc/**/*

# BindKey
# zle (Z-shell Line Editor)를 등록한 후, 단축키를 Binding 한다.
# zle -N src
# bindkey '^e' src # ^e를 누르면 src 명령어가 나간다.

# aliases
[ -f "$XDG_CONFIG_HOME/zsh/.aliases" ] && . "$XDG_CONFIG_HOME/zsh/.aliases"

#neofetch

