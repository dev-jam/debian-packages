#!/bin/sh

### XLibre modesetting 

## Modesetting configuration

mkdir -p /etc/X11/xorg.conf.d

cat > /etc/X11/xorg.conf.d/20-modesetting.conf << !
Section "Device"
    Identifier    "Intel or AMD GPU"
    Driver        "modesetting"
    Option        "ShadowFB"         "false"   # you don't need on recent hardware
    Option        "Atomic"           "true"    # only effective on Xlibre, or Xorg-git with a special patch
    Option        "TearFree"         "true"
    Option        "VariableRefresh"  "true"
EndSection
!

