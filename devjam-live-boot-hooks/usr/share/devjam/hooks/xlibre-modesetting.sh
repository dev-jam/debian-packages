#!/bin/sh

### XLibre modesetting
# Same OutputClass sections as the devjam-gpu-x11-xlibre-modesetting,
# -atomic and -asyncflip packages, which are not installed in the live image.
# TearFree is on by default in the modesetting driver of XLibre.

mkdir -p /etc/X11/xorg.conf.d

## Use the modesetting driver instead of an installed intel or amdgpu DDX

cat > /etc/X11/xorg.conf.d/20-devjam-modesetting.conf << !
Section "OutputClass"
    Identifier  "devjam modesetting"
    MatchDriver "i915|xe|amdgpu"
    Driver      "modesetting"
EndSection
!

## Atomic modesetting (default: off)

cat > /etc/X11/xorg.conf.d/30-devjam-modesetting-atomic.conf << !
Section "OutputClass"
    Identifier  "devjam modesetting atomic"
    MatchDriver "i915|xe|amdgpu"
    Option      "Atomic" "true"
EndSection
!

## Async flips on secondary outputs, for mirrored lab displays (default: off)

cat > /etc/X11/xorg.conf.d/30-devjam-modesetting-asyncflip.conf << !
Section "OutputClass"
    Identifier  "devjam modesetting asyncflip"
    MatchDriver "i915|xe|amdgpu"
    Option      "AsyncFlipSecondaries" "true"
EndSection
!
