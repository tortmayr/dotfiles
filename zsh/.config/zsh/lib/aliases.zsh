# Portable aliases. Anything that needs a GUI, a clipboard manager, a desktop
# notification daemon or a machine-specific path belongs in host.d/ instead.

# FZF aliases
alias fs='fzf --walker-skip .git,node_modules,target --preview "bat --color=always {}" --bind "ctrl-/:change-preview-window(down|hidden|)"'

#eza/ls aliases
alias tree="eza --tree"
alias ls='eza --icons'
alias lsa='ls -lah'
alias l='ls -lah'
alias ll='ls -lh'
alias la='ls -lAh'

# dir aliases
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'
alias -- -='cd -'

alias md='mkdir -p'
alias rd=rmdir

# fd aliases
alias ffd="fd"

# grep aliases

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Misc
alias c=clear

alias cgit='cdGit'
alias sgit='selectGit'
