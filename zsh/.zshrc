ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
	git
	fzf
	zsh-autosuggestions
	tmux
	fasd
	fzf-zsh-plugin
)

source $ZSH/oh-my-zsh.sh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# p10k
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k/p10k-instant-prompt-${(%):-%n}.zsh"
fi 
 [[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh

# nvm
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# zsh
alias ezr="vi $ZDOTDIR/.zshrc" # edit zshrc
alias eze="vi $HOME/.zshenv"

# find Port Num
port() {
    sudo lsof -nP -i4TCP:$1 | grep LISTEN
}
alias portall="sudo lsof -nP | grep LISTEN"

# vim
export PATH=/opt/nvim/bin:$PATH
alias vi="nvim"

# fzf
export FZF_DEFAULT_COMMAND="fd -t f"
[ -f $XDG_CACHE_HOME/fzf/fzf.zsh ] && source $XDG_CACHE_HOME/fzf/fzf.zsh

# fasd
alias v="f -e nvim"
alias o="a -e open"

# The Fuck
eval $(thefuck --alias)

# K8S
alias k="kubectl"
alias mk="minikube"
alias kgp="kubectl get pod -o wide"
source <(kubectl completion zsh)
source ~/.minikube/.minikube-completion
export KUBE_EDITOR="nvim"

# Bat
alias cat="bat"

# sdkman
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Auto Function
# 함수로 추가할 디렉토리를 auto complete 목록에 포함합니다.
# autoload에 zfunc이하 모든 항목을 선언합니다.
fpath=($fpath $ZDOTDIR/.zfunc)
autoload -Uz $ZDOTDIR/.zfunc/**/*

# BindKey
# zle (Z-shell Line Editor)를 등록한 후, 단축키를 Binding 한다.
# zle -N src
# bindkey '^e' src # ^e를 누르면 src 명령어가 나간다.
 
# trash-cli
alias rm="echo Use 'del' or 'trash', or the full path i.e. '/bin/rm'"
alias del="trash"

# asdf
. /opt/homebrew/opt/asdf/libexec/asdf.sh

# eza
eza_params=('--git' '--icons' '--classify' '--group-directories-first' '--time-style="+%y/%m/%d %H:%M"' '--group' '--color-scale')
alias ls="eza ${eza_params}"
alias l='ls -la'
alias la='ls -la'
alias lam='ls -la --sort=modified'
alias ll='ls -l'
alias llm='ls -l --sort=modified'
alias lt='ls --tree'
 
# htop
alias top="htop"

# tcping
alias ping="ping_or_tcping"
 
# lazygit
alias lg="lazygit"

#neofetch

