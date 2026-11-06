# Island

A dynamic-island style bar plugin for the Omarchy shell (Quickshell 0.3.2, Hyprland 0.56).
Work in progress: see the milestones below.

## Milestones
1. State.qml (state machine) + Theme.qml + idle/hover pill, tested in a `qs -p` rig
2. Morph animation, HUD, IPC and Hyprland shortcuts
3. Widgets (Wi-Fi, Bluetooth, audio, display, battery, calendar, world clock, power, theme, ...)
4. Cut over from jee.bar, retire the old control center (disabled, never deleted)

## Rollback
Restore the newest `~/.config/omarchy/shell.json.bak-island-*` and run `omarchy restart shell`.
