#!/usr/bin/env python3
"""Copy the island (and its optional OSD bridge) into the Omarchy plugin directory.

  python3 deploy.py          install both
  python3 deploy.py --no-osd install only the bar

Installing from git instead: `omarchy plugin add <git-url>` installs the bar alone;
the OSD bridge (osd/) is optional and only needed to route volume/brightness
popups into the island HUD.
"""
from pathlib import Path
import shutil, sys

src = Path(__file__).resolve().parent
plugins = Path.home() / ".config/omarchy/plugins"
SKIP = {"deploy.py", "README.md", "LICENSE", "rig.qml", "tools", "shims", "osd", "menu-shim", "notifications-shim", "components", "widgets", "services", "ipc", "menu-core", "Island.qml", "State.qml", "Theme.qml", "qmldir", "plan.md", ".git", "__pycache__", ".opencode", ".codex", "graphify-out"}

def copy_tree(source: Path, target: Path, skip=frozenset()):
    # Replace the plugin's OWN directory so deleted files don't linger.
    if target.exists():
        shutil.rmtree(target)
    target.mkdir(parents=True)
    for item in source.iterdir():
        if item.name in skip or item.name.endswith((".bak", "~")):
            continue
        if item.is_dir():
            shutil.copytree(item, target / item.name, ignore=shutil.ignore_patterns("*.bak*", "__pycache__"))
        else:
            shutil.copy2(item, target / item.name)

copy_tree(src, plugins / "io.github.aicyraa.island", SKIP)
print("Updated", plugins / "io.github.aicyraa.island")
if "--no-osd" not in sys.argv:
    copy_tree(src / "shims" / "osd", plugins / "io.github.aicyraa.island-osd")
    print("Updated", plugins / "io.github.aicyraa.island-osd")
if "--no-menu" not in sys.argv:
    copy_tree(src / "shims" / "menu", plugins / "io.github.aicyraa.island-menu")
    print("Updated", plugins / "io.github.aicyraa.island-menu")
if "--no-notifications" not in sys.argv:
    copy_tree(src / "shims" / "notifications", plugins / "io.github.aicyraa.island-notifications")
    print("Updated", plugins / "io.github.aicyraa.island-notifications")
