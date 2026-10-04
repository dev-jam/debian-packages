#!/bin/sh

cat > /etc/sddm.conf << !
[Autologin]
User=user
Session=kodi.desktop
!

if [ -e /etc/lightdm/lightdm.conf ]
then
	sed -i -r -e "s|^#.*autologin-user=.*\$|autologin-user=user|" \
		  -e "s|^#.*autologin-user-timeout=.*\$|autologin-user-timeout=0|" \
		  -e "s|^#.*autologin-session=.*\$|autologin-session=kodi.desktop|" \
	/etc/lightdm/lightdm.conf
fi

