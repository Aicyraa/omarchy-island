#!/usr/bin/env bash
# Put the previous bar back. Safe to run any time, including from a TTY.
#   ./rollback.sh            re-enable jee.bar, disable the island and its OSD bridge, restart the shell
# Everything is reversible: nothing is deleted.
set -u
omarchy plugin disable io.github.aicyraa.island-osd 2>/dev/null
omarchy plugin disable io.github.aicyraa.island 2>/dev/null
omarchy plugin enable jee.bar 2>/dev/null || omarchy plugin enable omarchy.bar
omarchy plugin enable omarchy.osd 2>/dev/null
omarchy restart shell
echo "If the bar is still wrong, restore the newest ~/.config/omarchy/shell.json.bak-island-* by hand."
