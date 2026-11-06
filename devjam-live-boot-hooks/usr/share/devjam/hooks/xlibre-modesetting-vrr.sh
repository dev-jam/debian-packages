#!/bin/sh

### XLibre modesetting with variable refresh rate
# xlibre-modesetting.sh plus the OutputClass section of the
# devjam-gpu-x11-xlibre-modesetting-vrr package. Not for experiments that
# need a fixed refresh rate.

sh /usr/share/devjam/hooks/xlibre-modesetting.sh

cat > /etc/X11/xorg.conf.d/30-devjam-modesetting-vrr.conf << !
Section "OutputClass"
    Identifier  "devjam modesetting vrr"
    MatchDriver "i915|xe|amdgpu"
    Option      "VariableRefresh" "true"
EndSection
!
