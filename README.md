# Island

A dynamic-island bar plugin for the Omarchy shell (Quickshell 0.3.2, Hyprland 0.56).
One pill, top-centre, that morphs between idle, hover, widget and HUD forms.

Status: milestone 2 of 4 (see the end of this file).

## Architecture

```
Bar.qml          plugin entry (manifest kind "bar"): Variants -> one Island per screen,
                 IPC loader, Hyprland global shortcuts, charger HUD
Island.qml       one PanelWindow per screen: fixed-size, transparent, click-masked,
                 containing the animated `pill`
State.qml        singleton "IslandState": the state machine (file is State.qml, type is
                 IslandState because QtQuick already has a type called State)
Theme.qml        singleton: palette -> semantic colour roles
services/        Net (Wi-Fi), Power (battery): native Quickshell modules, no polling
components/      Workspaces, WifiBars, BatteryIcon, ...
ipc/             HostIpc.qml (inside the shell) / PlainIpc.qml (test rig)
osd/             second tiny plugin that routes Omarchy's OSD calls to the island HUD
rig.qml          run the island beside your live bar: `qs -p rig.qml`
```

### Why the window never resizes
Resizing a layer-shell window makes the compositor reconfigure the surface on every
frame, which stutters. So the window is a fixed size (big enough for the largest
widget), transparent, and `mask: Region { item: zone }` makes everything outside the
pill click-through. Only the inner `pill` Rectangle animates. `exclusiveZone` is the
collapsed height, so tiled windows don't jump when the pill grows over them.

## The state machine (State.qml)

Four layers, each a flag that only its own functions touch:

| Layer        | Set by                         | Cleared by                                 |
|--------------|--------------------------------|--------------------------------------------|
| widget       | `openWidget` / `toggleWidget`  | Esc, click outside, same key, inactivity   |
| HUD          | `showHud` / `showHudPayload`   | 1.5 s timer                                |
| notification | (milestone 3)                  | timer                                      |
| hover        | pointer over pill 120 ms       | pointer away 300 ms                        |

`mode` is **derived**, never assigned: `widget > hud > notification > hover > idle`.
That is the whole trick. A lower layer can change its flag at any time, but `mode`
keeps showing the higher one, and when the higher layer ends `mode` falls back to
whatever is still active. Rapid keybind presses and hover flicker therefore cannot
leave it in a broken state. Opening widget B while A is open just changes
`widgetName`: A morphs straight into B without passing through idle.

Other rules: the inactivity timer re-arms while the pointer is over the pill or a key
was pressed in the last 3 s; widgets and HUD show only on the focused monitor (others
stay idle); the pill hides in fullscreen unless a widget is open.

## Driving it

```
omarchy-shell island toggle power        # inside the shell (fast socket path)
omarchy-shell island hud volume 60
omarchy-shell island hudJson '{"icon":"volume-high","value":"60","max":"100"}'
omarchy-shell island reducedMotion true
omarchy-shell island mode
```
Hyprland global shortcuts (no process spawned) are registered as `island:<widget>`:
`home wifi bluetooth audio display battery calendar worldclock power notifications
media system tray theme`. Bind with
`o.bind("SUPER + CTRL + Q", "Power", hl.dsp.global("island:power"))`.

## Theming
`Theme.qml` reads `~/.local/state/omarchy/current/theme/colors.toml` (the palette
every Omarchy theme ships) and maps it to roles: background, surface, surfaceRaised,
outline, text, textMuted, accent, accentText, success, warning, danger. A contrast
guard flips text to white/black if it falls under 4.5:1 on its surface. It reloads when
the file or `theme.generation` changes and cross-fades over 250 ms. The only hex
literals in the plugin are the fallback block in `Theme.qml`.

## Tuning cheat sheet (springs)

A `SpringAnimation` pulls a value toward its target like a spring pulls a weight.

- **spring (stiffness):** how hard it pulls. Higher = snappier and faster.
- **damping:** friction. Higher = the bounce dies sooner; low damping = wobbles for a while.
- **mass:** how heavy the weight is (QML default 1). Heavier = slower to start and stop.
  We leave it at 1 and tune the other two.
- **epsilon:** how close to the target counts as "arrived" (stops the animation).

| What                    | spring | damping | Why |
|-------------------------|--------|---------|-----|
| Pill width              | 3.4    | 0.26    | leads; a little overshoot reads as "springy" |
| Pill height             | 3.0    | 0.28    | follows 40 ms later and slightly softer |
| Capsule leading edge    | 5.0    | 0.38    | stiff + well damped: shoots ahead without wobble |
| Capsule trailing edge   | 2.0    | 0.30    | soft: lags, then catches up, which is the "liquid" stretch |
| HUD                     | (uses pill width/height) | | HUD is just another pill size |

Rules of thumb: more bounce -> lower damping. Snappier -> raise spring. If it feels
jittery at the end, raise epsilon or damping. `reducedMotion` turns every spring off
and sets durations to 0.

## Rollback
Restore the newest `~/.config/omarchy/shell.json.bak-island-*` and run
`omarchy restart shell` (not while the screen is locked).

## Milestones
1. State machine, theme, idle/hover pill (done)
2. IPC, Hyprland shortcuts, HUD routing, OSD bridge (done)
3. Widgets
4. Cut over from jee.bar, retire the old control center (disabled, never deleted)
