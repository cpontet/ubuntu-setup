# Bash aliases
# This file follows the .bash_aliases format: alias name='command'
# Lines starting with # are ignored, blank lines are ignored

# Shortcuts
alias c='clear'
alias g='git'
alias p='pnpm'
alias y='yarn'
alias b='bun'
alias br='bun run'

# Container
alias pod='podman'
alias docker='podman'

# Git
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias repos='cd ~/repos'

# Listing
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Tools
alias tf='terraform'
alias k='kubectl'
alias py='python3'
alias serve='python3 -m http.server'
alias bat='batcat'
alias fd='fdfind'
alias lg='lazygit'

# Misc
alias ports='ss -tulnp'
alias myip='curl -s ifconfig.me'
alias h='history'
