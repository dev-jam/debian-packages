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

### kwin tearfree

## Environment variables

mkdir -p /etc/profile.d

cat > /etc/profile.d/kwin_env.sh << !
export KWIN_PERSISTENT_VBO=1          # default?
export KWIN_USE_BUFFER_AGE=1          # default
export KWIN_EXPLICIT_SYNC=0           # Xorg takes care of it
export KWIN_X11_NO_SYNC_TO_VBLANK=1   # Xorg takes care of it
export KWIN_USE_INTEL_SWAP_EVENT=1    # not default, should be relevant only on glx, but we are going to use EGL
!

## Systemd services

mkdir -p /etc/systemd/user/plasma-kwin_x11.service.d

cat > /etc/systemd/user/plasma-kwin_x11.service.d/10-kwin_smoother.conf << !
[Service]
Environment="QSG_NO_VSINK=1"
!


## kwin EGL

## Environment variables

mkdir -p /etc/profile.d

cat > /etc/profile.d/egl.sh << !
export QT_XCB_GL_INTEGRATION=xcb_egl
export KWIN_OPENGL_INTERFACE=egl
export GST_GL_PLATFORM=egl    # this is not related to kwin, but it's useful
!


