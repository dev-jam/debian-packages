#!/bin/sh

# List of files to delete
files="
/etc/X11/xorg.conf.d/20-modesetting.conf
"

# Remove files if they exist
for file in $files; do
    [ -f "$file" ] && rm -v "$file" || echo "Skipping $file (does not exist)"
done
