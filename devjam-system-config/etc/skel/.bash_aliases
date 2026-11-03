# Sourced by ~/.bashrc (Debian's default ~/.bashrc reads ~/.bash_aliases)
# in every interactive bash shell, login or not.

# aliases
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -Iv'
alias la='ls -alh'
alias mkdir='mkdir -v'
alias df='df -h'
alias du='du -ch'
alias pbcopy='xsel --clipboard --input'
alias pbpaste='xsel --clipboard --output'

# enable bashrc.d directory
if [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/bashrc.d" ]; then
    for file in "${XDG_CONFIG_HOME:-$HOME/.config}/bashrc.d/"*.bashrc; do
        test -f "${file}" || continue
        . "${file}"
    done
    unset file
fi
