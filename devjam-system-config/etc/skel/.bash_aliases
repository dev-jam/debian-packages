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

# bash drop-in snippets (*.bashrc), in this order:
#   1. system-wide: /etc/bashrc.d/
#   2. per user:    ${XDG_CONFIG_HOME:-~/.config}/bashrc.d/
# A user snippet with the same file name as a system snippet replaces it;
# an empty user file of that name disables the system snippet.
__bashrc_d_user="${XDG_CONFIG_HOME:-$HOME/.config}/bashrc.d"
for __bashrc_d_file in /etc/bashrc.d/*.bashrc "$__bashrc_d_user"/*.bashrc; do
    [ -f "$__bashrc_d_file" ] || continue
    case "$__bashrc_d_file" in
        /etc/bashrc.d/*)
            [ -e "$__bashrc_d_user/${__bashrc_d_file##*/}" ] && continue ;;
    esac
    # shellcheck source=/dev/null
    . "$__bashrc_d_file"
done
unset __bashrc_d_user __bashrc_d_file
