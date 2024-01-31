if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# export PATH=$HOME/bin:/usr/local/bin:$PATH
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
	git
  fzf
  zsh-autosuggestions
  fasd
)

source $ZSH/oh-my-zsh.sh
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

neofetch

source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

export FZF_DEFAULT_COMMAND="fd -t f"

# find Port Num
port() {
    sudo lsof -nP -i4TCP:$1 | grep LISTEN
}
alias portall="sudo lsof -nP | grep LISTEN"

# vim
export PATH=/opt/nvim/bin:$PATH
alias vi="nvim"

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

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Auto Function
# 함수로 추가할 디렉토리를 auto complete 목록에 포함합니다.
# autoload에 zfunc이하 모든 항목을 선언합니다.
fpath=($fpath ~/.zfunc)
#autoload -Uz ~/.zfunc/**/*

# BindKey
# zle (Z-shell Line Editor)를 등록한 후, 단축키를 Binding 한다.
# zle -N src
# bindkey '^e' src # ^e를 누르면 src 명령어가 나간다.
 
# Go Path
export GOPATH=$HOME/.go
export GOMODCACHE=$GOPATH/pkg/mod
export PATH=$PATH:$GOPATH/bin

