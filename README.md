# debian-packages

Monorepo with the package trees for the custom Debian packages.

Each top-level directory is one binary package: the payload files (laid out as they are installed on the target system) plus a `DEBIAN/` directory with the control metadata. Packages are built with `dpkg-deb`, not with `debuild`/`dpkg-buildpackage`.

Built packages are published in the apt repository [`dev-jam/debian`](https://github.com/dev-jam/debian) (served at <https://dev-jam.github.io/debian/>). Installation instructions are in that repository's README.

---

## Packages

The packages in the *Science / lab setups* section are published in the `science` component of the apt repository. All other packages are published in the `main` component.

### Repository & packaging helpers

| Package | Purpose |
| --- | --- |
| `devjam-archive-keyring` | Signing key for the dev-jam apt repository |
| `devjam-archive-keyring-legacy` | Legacy variant of the keyring package |
| `devjam-external-keyring` | Signing keys for the external apt repositories |
| `devjam-external-keyring-legacy` | Legacy variant of the external keyring package |

### Tools & utilities

| Package | Purpose |
| --- | --- |
| `devjam-tools` | General scripts and utilities |
| `devjam-s-benchmark` | S benchmark suite for storage I/O responsiveness, copied to the disk under test with `s-benchmark-copy` |
| `apt-cleaner` | APT cleanup helper |
| `fclones-gui-launcher` | Launcher for the fclones GUI |
| `devjam-pipewire-scripts` | Switch between PipeWire and ALSA-only mode |

### System configuration

| Package | Purpose |
| --- | --- |
| `devjam-system-config` | System-level configuration and systemd tweaks |
| `devjam-system-config-lowlatency` | Low-latency system configuration |
| `devjam-system-config-rtirq` | rtirq configuration with real-time IRQ priorities for audio, USB, parallel port and GPU (diverts `/etc/rtirq.conf`) |
| `devjam-desktop-kernel-hardening` | Kernel hardening settings for desktops |
| `devjam-cpu-powercap` | CPU power cap permission for reading power usage |
| `devjam-sensors-asus-z790-plus-wifi` | Sensor configuration for the ASUS Z790-PLUS WIFI board |
| `devjam-live-boot-hooks` | Hooks for live-boot systems |
| `devjam-live-config` | Debian Live session settings: no wallet/keyring in the live session, groups of the live user |
| `devjam-conky-system-monitor` | Conky system monitor setup |

### Boot loader

| Package | Purpose |
| --- | --- |
| `devjam-grub-tools` | GRUB helper utilities and configuration |
| `devjam-grub-theme` | GRUB theme |

### Graphics & display

| Package | Purpose |
| --- | --- |
| `devjam-gpu-mesa-config` | Mesa configuration |
| `devjam-gpu-intel-config` | Intel GPU configuration |
| `devjam-gpu-brave-config` | GPU-related settings for Brave |
| `devjam-gpu-chromium-config` | GPU-related settings for Chromium |
| `devjam-gpu-x11-gtk4-vulkan` | X11 / GTK4 / Vulkan settings |
| `devjam-gpu-x11-synaptics-config` | X11 Synaptics touchpad configuration |
| `devjam-gpu-x11-xlibre-dmabuf` | DMA-BUF support for the XLibre server |
| `devjam-gpu-x11-xlibre-modesetting` | Use the XLibre modesetting driver on Intel and AMD GPUs (TearFree is on by default) |
| `devjam-gpu-x11-xlibre-amdgpu` | Use the amdgpu DDX on AMD GPUs with TearFree (conflicts with `devjam-gpu-x11-xlibre-modesetting`) |
| `devjam-gpu-x11-xlibre-modesetting-atomic` | Atomic mode setting for the modesetting driver |
| `devjam-gpu-x11-xlibre-vrr` | Variable refresh rate for the modesetting or amdgpu driver (not for lab timing) |
| `devjam-gpu-x11-xlibre-asyncflip` | Async flips on secondary outputs for the modesetting or amdgpu driver |
| `devjam-gpu-x11-xlibre-tearfree-plasma` | XLibre TearFree configuration (Plasma) |
| `devjam-gpu-x11-xlibre-tearfree-plasma-egl` | XLibre TearFree configuration (Plasma, EGL) |
| `devjam-x11-monitor-config` | X11 monitor configurations (e.g. display size) and a script to switch between them |

### Applications & desktop integration

| Package | Purpose |
| --- | --- |
| `brave-flags-wrapper` | Wrapper that applies persistent flags to Brave |
| `devjam-mpv-config` | mpv configuration |
| `devjam-kde-servicemenus` | KDE (Dolphin) service menus |
| `devjam-plasma-defaults` | System-wide KDE Plasma defaults (Dolphin, lock screen, SDDM theme and X options) |
| `devjam-thunar-actions` | Thunar custom actions |
| `devjam-wallpapers` | Desktop wallpapers |

### Science / lab setups

| Package | Purpose |
| --- | --- |
| `devjam-science-tools` | Tools for experimental lab setups |
| `devjam-science-experiment-mode` | Experiment mode: GRUB entries with isolated CPU cores per CPU preset, sound card IRQ pinning, no irqbalance, `switch-rtirq` to run rtirq only in experiment mode (depends on `devjam-system-config-rtirq`); how it works: [`README.md`](devjam-science-experiment-mode/usr/share/doc/devjam-science-experiment-mode/README.md) |
| `devjam-science-experiment-mode-rtirq` | Transitional package for `devjam-science-experiment-mode` (split into it and `devjam-system-config-rtirq`) |
| `devjam-science-opensesame-psychopy` | Settings and launch scripts for OpenSesame and PsychoPy, OpenSesame with real-time priority on the isolated CPUs of experiment mode |
| `devjam-science-tools-matlab` | MATLAB (and Psychtoolbox) launchers and KDE service menus |
| `devjam-science-kde-servicemenus` | KDE service menus for science, e.g. packing OpenSesame experiment folders into `.osexp` |
| `devjam-science-wallpapers` | CLS wallpapers for normal and experiment mode |

---

## Packaging standards

1. **Architecture**
   * Script-only packages (Bash, Perl, Python, config files) use `Architecture: all`.
   * Packages with compiled binaries use the native architecture, e.g. `Architecture: amd64`.

2. **Licensing (DEP-5)**
   * Every package ships a [DEP-5](https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/) copyright file, installed at `/usr/share/doc/<package>/copyright` as required by Debian Policy 12.5.
   * It lists upstream sources, per-file copyrights and licenses.
   * Common licenses (GPL, LGPL, Apache-2.0, ...) are referenced via `/usr/share/common-licenses/` instead of quoting the full text.

3. **Build settings**
   * `--root-owner-group` sets file ownership to `root:root` inside the archive.

---

## Building

Build with:

```bash
dpkg-deb --root-owner-group --build $PACKAGE_NAME .
```

The resulting `.deb` is written to the current directory.

### Checking a built package

```bash
dpkg-deb --info <package>.deb      # control metadata
dpkg-deb --contents <package>.deb  # payload, including usr/share/doc/<package>/copyright
lintian <package>.deb              # policy checks
```

---

## License

Copyright (C) 2021-2026 Bob Rosbag

Unless stated otherwise in the `copyright` file of a package, the packages in this repository are licensed under the GNU General Public License version 3 or (at your option) any later version (GPL-3.0-or-later). The full license text is in [`LICENSE`](LICENSE).

Some packages also contain files from others under their own license (for example Apache-2.0, GPL-2.0-only or GPL-2.0-or-later). The `copyright` file of each package lists the copyright and license per file.
