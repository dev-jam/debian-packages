#!/bin/sh
# Copyright (C) 2022-2026 Bob Rosbag <mail@bobrosbag.nl>
# SPDX-License-Identifier: GPL-3.0-or-later

mkdir -p /etc/X11/xorg.conf.d

cat > /etc/X11/xorg.conf.d/21-compositing-disabled.conf << !
Section "Extensions"
    Option "Composite" "Disable"
EndSection
!
