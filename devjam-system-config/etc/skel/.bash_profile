if [ -f ~/.profile ]; then
     . ~/.profile
fi

# enable .bashrc.d directory
# sources ~/bashrc.d
if [ -d "$HOME/.bashrc.d" ] ; then
    for file in ~/.bashrc.d/*.bashrc; do
       test -f "$file" || continue
       . "$file"
    done
fi



