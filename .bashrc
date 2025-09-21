# ~/.bashrc

# If not interactive, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History settings
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000

# Color prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\$ \[\033[00m\]'

# Enable color support for ls
alias ls='ls --color=auto'

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Load Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# AI Builder CLI
alias ai="~/bin/ai"

# Activate Python venv
if [ -d "$HOME/env" ]; then
    source ~/env/bin/activate
fi

# Do not auto install vosk here: it is built via GitHub
