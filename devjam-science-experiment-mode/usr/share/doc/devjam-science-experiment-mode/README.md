# Experiment mode: manual

Experiment mode is a boot option for lab computers that run timing-critical
experiments (OpenSesame and PsychoPy with EEG, button boxes, audio and
video). In the GRUB menu you pick an experiment mode entry; the kernel then
keeps a few CPU cores free of other work, and the experiment, the sound card
interrupts and the real-time interrupt threads get those cores.

Normal boot entries do not change. Experiment mode only applies when you
boot one of its entries.

Three packages work together:

| Package | Role |
| --- | --- |
| `devjam-science-experiment-mode` | GRUB entries with isolated CPUs, sound card IRQ pinning, no irqbalance, check tools |
| `devjam-system-config-rtirq` | rtirq configuration: real-time priorities for the IRQ threads of audio, USB, parallel port and GPU |
| `devjam-science-opensesame-psychopy` | OpenSesame with real-time priority, on the isolated CPUs |

`devjam-system-config-lowlatency` gives the `audio` group the real-time
limits that OpenSesame with real-time priority needs.

Contents: [Setting up](#setting-up-once-per-computer) ·
[Running an experiment](#running-an-experiment) ·
[Checking](#checking-that-it-works) · [Changing the setup](#changing-the-setup) ·
[How it works](#how-it-works) · [Troubleshooting](#troubleshooting) ·
[Things to know](#things-to-know) · [Commands and files](#commands-and-files) ·
[Sources](#sources)

## Setting up (once per computer)

What you have to do yourself is in steps 1 to 4 and 8. Everything else is
optional. You do not need to write any affinity or systemd files by hand:
the packages ship them, and the commands below change them for you.

1. **Install the packages.**

   ```bash
   sudo apt install devjam-science-experiment-mode \
       devjam-science-opensesame-psychopy devjam-system-config-lowlatency
   ```

2. **Check which CPUs share a core.** A preset should isolate whole cores:
   an isolated CPU still shares its core with its SMT sibling.

   ```bash
   lscpu --extended    # CPU and CORE columns
   cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list
   ```

   The default presets are `2,3`, `2-5` and `2-7`. They fit a CPU whose
   siblings are numbered next to each other (core 1 = CPUs 2 and 3, and so
   on). If your siblings are numbered differently, for example 2 and 10,
   choose your own presets in step 3. CPU 0 cannot be isolated.

3. **Switch the entries on.** Edit
   `/etc/default/grub.d/11_experiment_mode_defaults.cfg`:

   ```sh
   ENABLE_EXPERIMENT_MODE="true"
   DEFAULT_NR_ISO_CPU=6                              # preset at the top level
   EXPERIMENT_MODE_CPU_PRESETS="2,3 2-5 2-7"         # optional, this is the default
   GRUB_EXPERIMENT_MODE_DEFAULT=""                   # extra kernel parameters
   ```

   Then run `sudo update-grub`. Lines starting with `Experiment mode:` in its
   output are warnings about the presets (a CPU that does not exist, CPU 0,
   a half-isolated core).

4. **Make sure rtirq has IRQ threads.** rtirq only works with a PREEMPT_RT
   kernel or the kernel parameter `threadirqs`. Without them it does
   nothing. Add `threadirqs` either to `GRUB_CMDLINE_LINUX_DEFAULT` in
   `/etc/default/grub` (rtirq in both modes) or to
   `GRUB_EXPERIMENT_MODE_DEFAULT` (only in experiment mode), and run
   `sudo update-grub`. `verify-rtirq` shows whether IRQ threads exist.

5. **Optional: rtirq only in experiment mode.** By default rtirq runs in
   normal and in experiment mode.

   ```bash
   sudo switch-rtirq experiment    # back: sudo switch-rtirq always
   ```

6. **Optional: boot experiment mode by default.** Set `GRUB_DEFAULT=saved` in
   `/etc/default/grub` and run `sudo update-grub`. The experiment mode
   entries save themselves as default when they are booted, so the computer
   keeps starting the experiment mode entry you chose last.

7. **Users who run experiments** need the real-time limit of the `audio`
   group:

   ```bash
   sudo adduser USER audio    # then log out and in again
   ```

8. **Reboot**, choose an experiment mode entry, and check the result with
   `check-isolation -1` (see [Checking](#checking-that-it-works)).

## Running an experiment

1. Boot `Debian GNU/Linux - Experiment mode, 6 isolated CPUs (2-7)`, or
   another preset from `Experiment mode, other CPU presets`.
2. Start **OpenSesame 4.1 with PsychoPy (RT Priority)** from the menu.
   OpenSesame then runs with real-time priority (SCHED_RR 40) on the
   isolated CPUs of this boot. It follows the preset you chose in GRUB.
3. A USB audio interface can be plugged in before or after the boot: its
   IRQ is pinned to the isolated CPUs automatically.

What you do not have to do: stop irqbalance, pin sound card IRQs, start
rtirq, keep other programs off the isolated CPUs, or set the CPUs of
OpenSesame. Experiment mode does all of that.

The normal launcher **OpenSesame 4.1 with PsychoPy** starts OpenSesame
without real-time priority and on the normal CPUs, in both modes.

## Checking that it works

```bash
check-isolation -1      # once; without -1 it refreshes every 2 seconds
```

It shows, in this order:

- the mode, the kernel, whether IRQs are threaded, the isolated and
  `nohz_full` CPUs, `irqaffinity`, and the state of irqbalance, rtirq,
  auto-pin-audio and experiment-mode-cpus: `done` means the oneshot service
  has run, `skipped` that its condition did not hold (irqbalance in
  experiment mode, the others in normal mode);
- warnings, for example irqbalance running in experiment mode, or other
  processes that may run on the isolated CPUs;
- the IRQs that run on isolated CPUs: the sound cards (and the USB
  controller of a USB audio interface) belong there, other IRQs normally do
  not;
- per CPU (isolated ones marked `CPU*`): load, device IRQs, timer interrupts
  (`LOC`) and softirqs per second. An idle isolated CPU shows almost no
  `LOC`, `TIMER` and `RCU`.

More detail:

```bash
verify-rtirq            # priorities of the IRQ threads
check-rt-processes -1   # real-time threads with their CPUs (-a: also default kernel threads)
usb-affinity            # USB controllers, their IRQs and the devices behind them
journalctl -b -u auto-pin-audio.service   # which sound card IRQ went to which CPU
manage-opensesame-affinity --show         # CPU setting of OpenSesame (RT)
```

## Changing the setup

| What | How |
| --- | --- |
| Other CPU presets | `EXPERIMENT_MODE_CPU_PRESETS` in `/etc/default/grub.d/11_experiment_mode_defaults.cfg`, then `sudo update-grub` |
| Preset at the top level | `DEFAULT_NR_ISO_CPU` (number of CPUs of a preset, 0 for the preset without isolated CPUs), then `sudo update-grub` |
| Extra kernel parameters in experiment mode | `GRUB_EXPERIMENT_MODE_DEFAULT`, then `sudo update-grub` |
| Kernel of the top level entry | Newest Liquorix kernel, else newest kernel; `GRUB_TOP_LEVEL=/boot/vmlinuz-...` in `/etc/default/grub` chooses another one (GRUB 2.12 or later) |
| Let other processes use the isolated CPUs again | `sudo systemctl disable experiment-mode-cpus.service` (from the next boot), or `sudo /usr/lib/devjam/experiment-mode/confine-cpus --undo` (now, for new logins) |
| Fixed CPUs for OpenSesame (RT) | `manage-opensesame-affinity 2-5` (you), `--system 2-5` (all users); `--disable` goes back to the isolated CPUs |
| USB controller of a button box on an isolated CPU | `usb-affinity usb1 2` (until the next reboot; `usb-affinity` lists the buses) |
| rtirq only in experiment mode, or always | `sudo switch-rtirq experiment` / `sudo switch-rtirq always` |
| Priorities of rtirq | `/etc/rtirq.conf` (see `verify-rtirq`) |
| Remove the entries again | `ENABLE_EXPERIMENT_MODE="false"`, then `sudo update-grub` |

## How it works

```
GRUB: "Debian GNU/Linux - Experiment mode, 6 isolated CPUs (2-7)"
  kernel: isolcpus=managed_irq,domain,2-7 nohz_full=2-7 rcu_nocbs=2-7
          irqaffinity=0-1,8-15 experiment_mode=1
   |
   |  kernel: no other tasks, timer ticks, RCU callbacks or IRQs on CPUs 2-7
   v
systemd (ConditionKernelCommandLine on experiment_mode=1)
   |-- experiment-mode-cpus.service
   |                           services, VMs, login sessions -> CPUs 0-1,8-15
   |-- irqbalance.service      does not run
   |-- auto-pin-audio.service  sound card IRQs -> CPUs 2-7, round robin
   |                           (again for every sound card plugged in, via udev)
   |-- rtirq.service           IRQ threads get SCHED_FIFO priorities
   |   rtirq-resume.service    (always, or only in experiment mode: switch-rtirq)
   v
Menu entry "OpenSesame ... (RT Priority)"
   systemctl --user start opensesame-psychopy-rt.service
   -> SCHED_RR priority 40, on CPUs 2-7 (the isolated CPUs of this boot)
```

### GRUB entries

`/etc/grub.d/11_experiment_mode` runs during `update-grub` and calls
`/usr/lib/devjam/experiment-mode/grub-entries`. That script runs GRUB's own
`/etc/grub.d/10_linux` once per CPU preset, with the experiment mode
parameters added to `GRUB_CMDLINE_LINUX_DEFAULT`. The entries therefore boot
exactly like the normal ones (root device, separate `/boot`, LVM, LUKS,
btrfs, `GRUB_CMDLINE_LINUX`). The kernel packages run `update-grub` after
every kernel installation or removal, so the entries always list the
installed kernels.

Menu layout:

- `<OS> - Experiment mode, N isolated CPUs (list)`: the preset of
  `DEFAULT_NR_ISO_CPU`, with the top level kernel
- `Advanced options for <OS> - Experiment mode, ...`: every kernel
- `Experiment mode, other CPU presets`: the same for each other preset,
  including one without isolated CPUs (only `experiment_mode=1`)

The kernel parameters of a preset:

| Parameter | Effect |
| --- | --- |
| `isolcpus=managed_irq,domain,<cpus>` | No other tasks and no load balancing on these CPUs; managed IRQs (such as NVMe queues) avoid them where possible |
| `nohz_full=<cpus>` | No timer tick while one task runs (needs `CONFIG_NO_HZ_FULL` in the kernel) |
| `rcu_nocbs=<cpus>` | RCU callbacks run on the other CPUs |
| `irqaffinity=<other cpus>` | All IRQs start on the other CPUs; auto-pin-audio and usb-affinity move chosen ones to the isolated CPUs |
| `experiment_mode=1` | Switch for the systemd units |

The entry IDs start with `experiment-<preset>-` (for example
`experiment-2-7-gnulinux-simple-<uuid>`), so they differ from those of the
normal entries; `GRUB_DEFAULT` can name one.

### Sound card IRQs

`auto-pin-audio-irq` (run by `auto-pin-audio.service`) takes every sound
card in `/sys/class/sound`, finds the PCI device above it and pins that
device's IRQs to the isolated CPUs, one CPU per IRQ in turn. For a USB audio
interface this is the IRQ of its USB host controller: a USB device has no
IRQ of its own, so the other devices on that controller (button box,
keyboard) share it. The service runs at boot and, through
`99-auto-pin-audio.rules`, for every sound card that is added later.

### irqbalance

irqbalance moves IRQs between CPUs and by default never places them on
isolated or `nohz_full` CPUs, so it would undo the pinning. The drop-in
`/usr/lib/systemd/system/irqbalance.service.d/disable-experiment.conf` sets
`ConditionKernelCommandLine=!experiment_mode=1`: in experiment mode
irqbalance is skipped, in normal mode it starts as usual when it is
installed and enabled. Without irqbalance the drop-in does nothing.
`check-isolation` warns when irqbalance runs while CPUs are isolated.

### rtirq

rtirq gives the IRQ threads of the drivers in `RTIRQ_NAME_LIST`
(`/etc/rtirq.conf`) a SCHED_FIFO priority: `snd` 90, `snd-usb` 85, `usb` 80,
`parport` 75, `i915` 70. It does not change on which CPUs IRQs run.
`switch-rtirq experiment` adds a drop-in with
`ConditionKernelCommandLine=experiment_mode=1` to `rtirq.service` and to
`rtirq-resume.service`, which also runs `rtirq start` (at boot and after
suspend).

### Other processes

`isolcpus=` takes the isolated CPUs out of the affinity of PID 1, and new
processes normally inherit that. That breaks once the cpuset controller of
cgroup v2 is on, which Docker, containerd and other units with
`Delegate=yes` do. systemd starts every service with
`clone3(CLONE_INTO_CGROUP)`, the new process lands in another cpuset than
PID 1, and the kernel gives it every CPU of that cpuset, the isolated ones
included (`cpuset_fork` in `kernel/cgroup/cpuset.c`). Every service and the
whole user session then have all CPUs, and a load test showed normal
processes running on the isolated CPUs.

`experiment-mode-cpus.service` runs `confine-cpus` at boot, before the first
login, and limits until the next reboot:

| What | Setting |
| --- | --- |
| `system.slice` (services), `machine.slice` (virtual machines, containers) | `AllowedCPUs=` the other CPUs |
| `session-*.scope` (login sessions) | `AllowedCPUs=` the other CPUs |
| `user@.service` (the user service manager) | `CPUAffinity=` the other CPUs; user units inherit it |

The settings are runtime drop-ins in `/run/systemd/system` and
`systemctl set-property --runtime`. `user.slice` itself stays unlimited:
OpenSesame (RT) is a user service, and its launcher pins it to the
isolated CPUs. A program can still pin itself to an isolated CPU on
purpose; `isolcpus=` never prevents that.

### OpenSesame with real-time priority

The menu entry starts the user service `opensesame-psychopy-rt.service`
(`systemctl --user start`). The service runs OpenSesame with SCHED_RR
priority 40 and sets `OPENSESAME_CPUS=isolated`, which makes
`opensesame-psychopy-launch` start OpenSesame with `taskset` on the CPUs in
`/sys/devices/system/cpu/isolated`, unless the service has a
`CPUAffinity=` (see below). Without isolated CPUs (normal mode) it keeps
the CPUs it inherits.

The launcher sets the CPUs itself because the inherited affinity cannot be
trusted (see [Other processes](#other-processes)).

`manage-opensesame-affinity` writes a drop-in for this service with
`CPUAffinity=` (and an empty `OPENSESAME_CPUS`), in
`~/.config/systemd/user/opensesame-psychopy-rt.service.d/cpu-affinity.conf`
or, with `--system`, in `/etc/systemd/user/...`. A user drop-in replaces the
system one. Such fixed CPUs apply in normal mode too.

## Troubleshooting

| Problem | Cause and fix |
| --- | --- |
| No experiment mode entries in GRUB | `ENABLE_EXPERIMENT_MODE` is not `"true"`, or `update-grub` did not run; check the `Experiment mode:` lines in its output |
| A preset is missing | `update-grub` skipped it: CPU 0, a CPU that does not exist, or an invalid list |
| OpenSesame (RT) does not start | `journalctl --user -u opensesame-psychopy-rt`; usually the user has no real-time limit: add the user to `audio` (setup step 7) and log in again |
| OpenSesame (RT) runs on the wrong CPUs | `check-rt-processes -1` shows its CPUs (column CPUS); `manage-opensesame-affinity --show` shows a drop-in with fixed CPUs, which wins; `--disable` (and `--system --disable`) removes it. Started OpenSesame before the 1.10-1 update? Close it and start it again |
| `check-isolation` warns that irqbalance runs | `systemctl cat irqbalance.service` should show the drop-in `disable-experiment.conf`; was the computer booted with `experiment_mode=1`? |
| "no threaded IRQs" | rtirq has nothing to prioritize; add `threadirqs` (setup step 4) |
| "nohz_full= is set but not active" | The kernel lacks `CONFIG_NO_HZ_FULL`: `grep NO_HZ_FULL /boot/config-$(uname -r)` |
| A sound card IRQ shows "unchanged" | `journalctl -b -u auto-pin-audio.service`; a managed IRQ is placed by the kernel and cannot be moved |
| "N processes may also run on the isolated CPUs" | `systemctl status experiment-mode-cpus.service`: did it run? Sessions that started before it keep all CPUs: log in again. Processes started outside systemd's slices are not covered |
| Other IRQs on isolated CPUs | Pinned by hand (`usb-affinity`), or a managed IRQ whose queue has only isolated CPUs |

## Things to know

- **No load balancing between isolated CPUs.** The scheduler does not move
  tasks between CPUs isolated with `isolcpus=domain`. A program with several
  normal (SCHED_OTHER) threads can keep them all on one isolated CPU. The
  real-time scheduler does move real-time threads, such as those of
  OpenSesame (RT), between the isolated CPUs. Give a program as many
  isolated CPUs as it really uses.
- **SMT.** An isolated CPU still shares its core with its SMT sibling. The
  kernel documentation advises against SMT for isolation (`nosmt`). Switch
  SMT at boot rather than during an experiment: `smt-manager` takes CPUs
  offline and online (CPU hotplug), and then the kernel sets every task in
  a cpuset to the CPUs of that cpuset (`cpuset_update_tasks_cpumask`), and
  the IRQs of a CPU that goes offline move to other CPUs.
- **Normal processes on isolated CPUs cost OpenSesame time.** SCHED_RR 40
  wins from normal tasks, but the kernel gives normal tasks up to 50 ms per
  1000 ms on every CPU through its fair server (`sched_init_dl_servers` in
  `kernel/sched/deadline.c`). That is why experiment-mode-cpus.service keeps
  them away. Count the affinities with
  `for p in /proc/[0-9]*; do awk '/^Cpus_allowed_list/ {print $2}' "$p/status"; done | sort | uniq -c`.
- **Services that set their own CPUs** lose them when
  experiment-mode-cpus.service limits `system.slice`, if they started
  before it; Docker containers with `--cpuset-cpus` on isolated CPUs do not
  start in experiment mode.
- **The isolated CPUs are fixed per boot.** Choosing another preset means
  rebooting.
- **USB controller pinning by hand** (`usb-affinity`) lasts until the next
  reboot. The controller of a USB audio interface is pinned automatically.
- **PipeWire** runs on the normal CPUs: its `CPUAffinity` in
  devjam-system-config-lowlatency is commented out.
- **Liquorix at the top level** needs GRUB 2.12 or later
  (`GRUB_TOP_LEVEL`); older GRUB puts the newest kernel there.
- **USB audio and rtirq.** For `snd-usb`, rtirq only finds USB controllers
  directly on the root PCI bus; a USB audio interface still gets priority 80
  through `usb`.

## Commands and files

| Command | Package | Purpose |
| --- | --- | --- |
| `check-isolation [-1] [SECONDS]` | experiment-mode | Boot settings, IRQs on isolated CPUs, load and interrupts per CPU |
| `usb-affinity [usbN CPU-LIST]` | experiment-mode | USB controllers, their IRQs and devices; pin a controller's IRQs (needs root) |
| `switch-rtirq [experiment\|always]` | experiment-mode | Run rtirq only in experiment mode, or always (needs root) |
| `verify-rtirq` | rtirq | The priorities rtirq set, and whether IRQ threads exist |
| `check-rt-processes [-1] [SECONDS]` | rtirq | All real-time threads |
| `manage-opensesame-affinity` | opensesame-psychopy | CPUs of OpenSesame (RT) |

| File | Purpose |
| --- | --- |
| `/etc/default/grub.d/11_experiment_mode_defaults.cfg` | Settings of the GRUB entries |
| `/etc/grub.d/11_experiment_mode`, `/usr/lib/devjam/experiment-mode/grub-entries` | Make the GRUB entries during `update-grub` |
| `/usr/lib/systemd/system/auto-pin-audio.service`, `/usr/lib/udev/rules.d/99-auto-pin-audio.rules` | Pin sound card IRQs in experiment mode |
| `/usr/lib/systemd/system/irqbalance.service.d/disable-experiment.conf` | No irqbalance in experiment mode |
| `/usr/lib/systemd/system/experiment-mode-cpus.service`, `/usr/lib/devjam/experiment-mode/confine-cpus` | Keep other processes off the isolated CPUs in experiment mode |
| `/run/systemd/system/{user@.service,session-.scope,machine.slice}.d/50-experiment-mode-cpus.conf` | Made by `confine-cpus`, gone after reboot |
| `/etc/systemd/system/rtirq.service.d/experiment_mode.conf`, `.../rtirq-resume.service.d/...` | Made by `switch-rtirq experiment` |
| `/etc/rtirq.conf` | rtirq priorities (diverted by devjam-system-config-rtirq) |
| `/usr/lib/systemd/user/opensesame-psychopy-rt.service` | OpenSesame with real-time priority |
| `~/.config/systemd/user/opensesame-psychopy-rt.service.d/cpu-affinity.conf` | Made by `manage-opensesame-affinity` (`/etc/systemd/user/...` with `--system`) |

## Sources

- Linux kernel, `Documentation/admin-guide/cpu-isolation.rst` and
  `Documentation/admin-guide/kernel-parameters.txt` (isolcpus, nohz_full,
  irqaffinity, threadirqs).
- Linux kernel, `Documentation/ABI/testing/sysfs-devices-system-cpu`
  (`/sys/devices/system/cpu/isolated`) and `sysfs-bus-pci` (`msi_irqs`,
  `irq`).
- Linux kernel, `kernel/irq/irqdesc.c` (default IRQ affinity is all CPUs
  unless `irqaffinity=` is given), `kernel/sched/topology.c` and
  `kernel/sched/rt.c` (isolated CPUs share the default root domain, in which
  the real-time scheduler places real-time threads).
- irqbalance(1) and `cputree.c`: isolated and `nohz_full` CPUs are banned by
  default.
- rtirq (`rtirq.sh`, rncbc/rtirq): only IRQ thread priorities, needs
  PREEMPT_RT or threadirqs.
- systemd.unit(5): `ConditionKernelCommandLine=`, drop-ins for unit name
  prefixes (`session-.scope.d/`); systemd.resource-control(5):
  `AllowedCPUs=`; systemd source `src/core/exec-invoke.c` (affinity only
  with `CPUAffinity=`), `src/core/scope.c` (scopes load drop-ins).
- Linux kernel, `kernel/cgroup/cpuset.c` (`cpuset_fork`, `cpuset_attach`)
  and `kernel/sched/deadline.c` (fair server, 50 ms per 1000 ms).
