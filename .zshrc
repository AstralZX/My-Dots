#!/usr/bin/env zsh


HISTSIZE=50000
SAVEHIST=50000
HISTFILE="$HOME/.zsh_history"
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS


autoload -Uz compinit && compinit -C
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'


bindkey -e
bindkey "^[[3~" delete-char
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^[[5~" up-line-or-history
bindkey "^[[6~" down-line-or-history

setopt AUTO_CD
setopt EXTENDED_GLOB
setopt NUMERIC_GLOB_SORT
setopt INTERACTIVE_COMMENTS


for plugin in "$HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" \
              "$HOME/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
  [[ -f "$plugin" ]] && source "$plugin"
done


alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -1'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias cat='bat --style=plain --paging=never 2>/dev/null || cat'
alias ping='ping -c 5'
alias mkdir='mkdir -p'
alias vi='nvim 2>/dev/null || vim'
alias vim='nvim 2>/dev/null || vim'
alias please='sudo $(fc -ln -1)'
alias up='sudo pacman -Syu'
alias upd='sudo pacman -Syyu'
alias install='sudo pacman -S'
alias remove='sudo pacman -Rns'
alias search='pacman -Ss'
alias orphans='sudo pacman -Rns $(pacman -Qtdq)'
alias clean='sudo pacman -Sc'
alias yeet='sudo pacman -Rns'
alias :q='exit'
alias c='clear'
alias h='history'
alias path='echo -e ${PATH//:/\\n}'
alias ports='ss -tulanp'
alias ip='ip -c'


export PATH="$HOME/.local/bin:$HOME/bin:$PATH"


export EDITOR='zed'
export VISUAL='zed'


[[ -f /usr/local/bin/starship ]] && eval "$(starship init zsh)"


pfetch

export PATH=$PATH:/home/perfect/.spicetify
