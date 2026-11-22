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


installed = {}
for dist in distributions():
    name = dist.metadata["Name"]
    if name:
        installed[canonical(name)] = dist.version

missing = []
for spec in filter(None, sys.argv[1].split(",")):
    if "PyGaze" in spec:
        name = "python-pygaze"
    elif spec.startswith("git+"):
        name = spec.rstrip("/").rsplit("/", 1)[-1].removesuffix(".git")
    elif spec.startswith(("http://", "https://")):
        # Wheel file name: <name>-<version>-...
        name = spec.rsplit("/", 1)[-1].split("-", 1)[0]
    else:
        name = re.split(r"[<>=!~\[; ]", spec, maxsplit=1)[0]
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
