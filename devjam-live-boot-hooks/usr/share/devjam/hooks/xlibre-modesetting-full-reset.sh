#!/bin/sh

# List of files to delete
files="
/etc/X11/xorg.conf.d/20-modesetting.conf
/etc/profile.d/kwin_env.sh
/etc/systemd/user/plasma-kwin_x11.service.d/10-kwin_smoother.conf
/etc/profile.d/egl.sh
"

# Remove files if they exist
for file in $files; do
    [ -f "$file" ] && rm -v "$file" || echo "Skipping $file (does not exist)"
done
