#!/bin/sh
# Copyright (C) 2022-2026 Bob Rosbag <mail@bobrosbag.nl>
# SPDX-License-Identifier: GPL-3.0-or-later

### XLibre modesetting with variable refresh rate
# xlibre-modesetting.sh plus the OutputClass section of the
# devjam-gpu-x11-xlibre-vrr package. Not for experiments that need a fixed
# refresh rate.

sh /usr/share/devjam/hooks/xlibre-modesetting.sh

cat > /etc/X11/xorg.conf.d/30-devjam-vrr.conf << !
Section "OutputClass"
    Identifier  "devjam vrr"
    MatchDriver "i915|xe|amdgpu"
    Option      "VariableRefresh" "true"
EndSection
!
