#!/bin/sh

mkdir -p /etc/X11/xorg.conf.d

cat > /etc/X11/xorg.conf.d/21-compositing-enabled.conf << !
Section "Extensions"
    Option "Composite" "Enable"
EndSection
!

