# debian-packages

Monorepo with the package trees for the custom Debian packages.

Each top-level directory is one binary package: the payload files (laid out as they are installed on the target system) plus a `DEBIAN/` directory with the control metadata. Packages are built with `dpkg-deb`, not with `debuild`/`dpkg-buildpackage`.

Built packages are published in the apt repository [`dev-jam/debian-repo`](https://github.com/dev-jam/debian-repo).

---

## Packages

### Repository & packaging helpers

| Package | Purpose |
| --- | --- |
| `devjam-archive-keyring` | Signing key for the dev-jam apt repository |
| `devjam-archive-keyring-legacy` | Legacy variant of the keyring package |

### Tools & utilities

| Package | Purpose |
| --- | --- |
| `devjam-tools` | General scripts and utilities (`mkvdts2ac3.sh`, `alsa-capabilities`, `smt-manager.pl`, ...) |
| `apt-cleaner` | APT cleanup helper |
| `fclones-gui-launcher` | Launcher for the fclones GUI |
| `devjam-pipewire-scripts` | PipeWire helper scripts |

### System configuration

| Package | Purpose |
| --- | --- |
| `devjam-system-config` | System-level configuration and systemd tweaks |
| `devjam-system-config-lowlatency` | Low-latency system configuration |
| `devjam-desktop-kernel-hardening` | Kernel hardening settings for desktops |
| `devjam-cpu-powercap` | CPU power capping |
| `devjam-sensors-asus-z790-plus-wifi` | Sensor configuration for the ASUS Z790-PLUS WIFI board |
| `devjam-live-boot-hooks` | Hooks for live-boot systems |
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
| `devjam-gpu-x11-xlibre-tearfree-amdgpu` | XLibre TearFree configuration (amdgpu) |
| `devjam-gpu-x11-xlibre-tearfree-modesetting` | XLibre TearFree configuration (modesetting) |
| `devjam-gpu-x11-xlibre-tearfree-plasma` | XLibre TearFree configuration (Plasma) |
| `devjam-gpu-x11-xlibre-tearfree-plasma-egl` | XLibre TearFree configuration (Plasma, EGL) |
| `devjam-x11-monitor-config` | Display and monitor profile management |

### Applications & desktop integration

| Package | Purpose |
| --- | --- |
| `brave-flags-wrapper` | Wrapper that applies persistent flags to Brave |
| `devjam-mpv-config` | mpv configuration |
| `devjam-kde-servicemenus` | KDE (Dolphin) service menus |
| `devjam-thunar-actions` | Thunar custom actions |

### Science / lab setups

| Package | Purpose |
| --- | --- |
| `devjam-science-tools` | Tools for experimental lab setups |
| `devjam-science-experiment-mode-rtirq` | Real-time IRQ tuning for experiment mode |
| `devjam-science-opensesame-psychopy` | Settings and launch scripts for OpenSesame and PsychoPy |

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

See the individual `copyright` file of each package.
