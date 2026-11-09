# shellcheck shell=bash
# Bash history size (system-wide default; override per user with
# ~/.config/bashrc.d/history.bashrc).
#
# HISTFILESIZE: lines kept in ~/.bash_history. hstr searches this file, so this
#               is how far back Ctrl-R reaches.
# HISTSIZE:     commands kept in memory per shell (arrow-up, `history`).
#               Kept lower, as every open shell holds this list in memory.
# hstr.bashrc deliberately leaves both out, so the order of loading is irrelevant.
export HISTFILESIZE=100000
export HISTSIZE=10000
export HISTTIMEFORMAT="%F %T "
export HISTIGNORE="ls:ll:la:cd:pwd:clear:exit:history"
