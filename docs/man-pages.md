# Man pages

Debian Policy (section 12.1) says that each program, utility and function
should have an associated manual page. None of the commands in these
packages has one yet, so lintian reports `no-manual-page` for 82 commands.
The warning is overridden in each package (`usr/share/lintian/overrides/`)
until man pages are written; this file records which commands actually need
one.

The "help" column says whether the script appears to handle `--help` or
print a usage text (a rough check with grep, not verified per script).
Scripts that do are candidates for `help2man`, which generates a man page
from the `--help` output.

Removing a package's `no-manual-page` override line shows the remaining
warnings again.

## Priority 1: lab users and lab administrators

Commands that people other than the maintainer run from a terminal, or
that change system behaviour. These need a man page most.

| Package | Command | Help | Purpose |
|---|---|---|---|
| devjam-science-experiment-mode-rtirq | `switch-rtirq` | no | Link or unlink rtirq to experiment mode |
| devjam-science-experiment-mode-rtirq | `verify-rtirq` | no | Show the IRQ pinning rtirq applied |
| devjam-science-experiment-mode-rtirq | `check-isolation` | yes | Check CPU isolation in experiment mode |
| devjam-science-experiment-mode-rtirq | `check-rt-processes` | no | List real-time processes |
| devjam-science-experiment-mode-rtirq | `usb-affinity` | yes | USB tree with controller IRQs and CPU affinity |
| devjam-science-experiment-mode-rtirq | `update-grub-custom-experiment-mode` | no | Generate the experiment mode GRUB entries |
| devjam-science-opensesame-psychopy | `manage-opensesame-affinity` | yes | Set the CPU affinity of OpenSesame |
| devjam-science-tools | `install-psychopy-opensesame` | yes | Install PsychoPy with OpenSesame |
| devjam-science-tools | `print-system-information` | no | Hardware and software report |
| devjam-science-tools | `make-osexp` | yes | Pack a folder as an OpenSesame experiment |
| devjam-science-tools | `update-tobii-etm` | yes | Download or update Tobii Pro Eye Tracker Manager |
| devjam-science-tools-matlab | `matlab-run-cli-bg` | yes | Run a MATLAB script without GUI |
| devjam-science-tools-matlab | `matlab-run-cli-exp` | yes | Run a MATLAB script with Psychtoolbox |
| devjam-mpv-config | `switch-mpv-config` | yes | Choose the mpv profile for a lab monitor |
| devjam-x11-monitor-config | `switch-x11-monitor` | yes | Choose the X11 profile for a lab monitor |
| devjam-system-config | `switch-io` | no | Choose an I/O scheduler preset |
| devjam-pipewire-scripts | `switch2alsa`, `switch2alsa-persistent`, `switch2pipewire`, `switch2pipewire-persistent`, `pipewire-restart` | no | Switch between PipeWire and ALSA only mode (one shared man page would do) |

## Priority 2: maintainer and build tooling

Commands with options that are mostly used by the maintainer. Most already
print a usage text, so `help2man` is cheap here.

| Package | Command | Help | Purpose |
|---|---|---|---|
| devjam-tools | `build-deb-package` | yes | Build package trees with dpkg-deb and lintian |
| devjam-tools | `bpo-build`, `bpo-build-host`, `bpo-resume` | yes | Backport builds from apt source |
| devjam-tools | `sbuild-local` | yes | Isolated package build |
| devjam-tools | `appimage2deb` | yes | Repackage an AppImage as a .deb |
| devjam-tools | `update-local-debs` | yes | Update upstream GitHub .debs in a local apt repository |
| devjam-tools | `update-artcraft-repo` | yes | Update the ArtCraft debs in a local apt repository |
| devjam-tools | `nspawn` | yes | systemd-nspawn wrapper for live-build and rescue |
| devjam-tools | `audio-monitor` | yes | Monitor ALSA cards |
| devjam-tools | `smart-menu` | no | Interactive SMART menu for SATA and NVMe disks |
| devjam-tools | `tar-all-files` | yes | Create tar archives with gz, lz4 or zstd |
| devjam-tools | `aud-convert-codec`, `aud-convert-channels` | yes | Convert audio files (also used from service menus) |
| devjam-tools | `vid-convert-codec`, `vid-convert-container` | yes | Convert or remux video files (also used from service menus) |

Third-party scripts: check first whether upstream ships a man page that can
be installed as is.

| Package | Command | Help | Upstream |
|---|---|---|---|
| devjam-tools | `alsa-capabilities` | yes | Ronald van Engelen |
| devjam-tools | `mkvdts2ac3` | yes | Jake Wharton, Chris Hoekstra |
| devjam-tools | `smt-manager` | yes | Steven Barrett |

## No man page needed

These are not meant to be run by hand from a terminal, or the man page of
another program already covers them. A `no-manual-page` override per file
is the honest long-term answer for these.

- **Wrappers that replace another program's command**, whose own man page
  applies: `brave-browser-stable`, `brave-origin-stable`
  (brave-flags-wrapper), `thunar` (devjam-thunar-actions).
- **Backends of desktop entries and service menus**:
  `system-clean-apt` (apt-cleaner), `opensesame-psychopy-launch`,
  `sigmund-analyst-psychopy-launch`, `plasma-restart`, `apply-plasma-theme`,
  `check-flac`, `csv2tsv`, `evtx2xml`, `change-fourcc`,
  `convert-folder-to-video-iso`, `copy-quoted-paths`, `compare-diffoscope`,
  `extract-microvideo`, `mediainfo-gui-multi`, `check-dupes-fclones`,
  `check-dupes-isolate-fclones`, `check-unique-fclones`,
  `check-unique-isolate-fclones`.
- **Run by systemd**: `auto-pin-audio-irq` (auto-pin-audio.service).
- **Short personal admin helpers without options**: `composite-enable`,
  `composite-disable`, `suspend-enable`, `suspend-disable`, `fstrim-all`,
  `fstrim-home`, `dkms-rebuild`, `lb-build`, `lb-rebuild`, `dl-build`,
  `dl-rebuild`, `ptb-update`, `testing-debsecan`,
  `virtualbox-install-extpack`, `adduser2defaultgroups`,
  `check-io-schedulers`, `systemd-find-junk`, `testx`, `setup-user-links`,
  `update-psychopy-installer`.

If one of these grows options or is handed to other users, move it to one
of the priority lists above.
