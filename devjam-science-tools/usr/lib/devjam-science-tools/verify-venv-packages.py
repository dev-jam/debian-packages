"""Check that every requested package is installed in this Python environment.

Run with the venv's Python. Argument: the comma-separated package list that
install-psychopy-opensesame passed to psychopy_linux_installer. Prints the
versions of the key packages and exits 1 when a requested package is missing.
"""
# Copyright (C) 2026 Bob Rosbag <mail@bobrosbag.nl>
# SPDX-License-Identifier: GPL-3.0-or-later

import re
import sys
from importlib.metadata import distributions


def canonical(name):
    return re.sub(r"[-_.]+", "-", name).lower()


def requirement_name(spec):
    """Package name of one entry, by the rules of install-psychopy-opensesame.

    name@<url> (PEP 508 direct reference) gives the name before the @, a
    wheel URL the name in its file name, a plain requirement its name.
    """
    match = re.match(r"([A-Za-z0-9][A-Za-z0-9._-]*)\s*@", spec)
    if match:
        return match.group(1)
    url = spec.split("#", 1)[0]
    if "://" in url and url.endswith(".whl"):
        # Wheel file name: <name>-<version>-...
        return url.rsplit("/", 1)[-1].split("-", 1)[0]
    return re.split(r"[<>=!~\[;@ ]", spec, maxsplit=1)[0]


installed = {}
for dist in distributions():
    name = dist.metadata["Name"]
    if name:
        installed[canonical(name)] = dist.version

missing = []
for spec in filter(None, sys.argv[1].split(",")):
    name = requirement_name(spec)
    if canonical(name) not in installed:
        missing.append(name)

for name in ("python", "opensesame-core", "psychopy", "psychopy-app",
             "pyqt-code-editor", "opensesame-extension-sigmund",
             "wxpython", "pyglet", "pygame", "numpy"):
    if name == "python":
        version = sys.version.split()[0]
    else:
        version = installed.get(name, "not installed")
    print(f"       {name:32} {version}")

sys.stdout.flush()
if missing:
    print("ERROR: not installed: " + ", ".join(missing), file=sys.stderr)
    sys.exit(1)
print("All requested packages are installed.")
