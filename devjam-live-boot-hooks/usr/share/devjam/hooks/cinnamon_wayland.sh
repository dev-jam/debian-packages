#!/bin/sh
# Copyright (C) 2022-2026 Bob Rosbag <mail@bobrosbag.nl>
# SPDX-License-Identifier: GPL-3.0-or-later

cat > /etc/sddm.conf << !
[Autologin]
User=user
Session=cinnamon-wayland.desktop
!

if [ -e /etc/lightdm/lightdm.conf ]
then
	sed -i -r -e "s|^#.*autologin-user=.*\$|autologin-user=user|" \
		  -e "s|^#.*autologin-user-timeout=.*\$|autologin-user-timeout=0|" \
		  -e "s|^#.*autologin-session=.*\$|autologin-session=cinnamon-wayland.desktop|" \
	/etc/lightdm/lightdm.conf
fi

