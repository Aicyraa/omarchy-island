# Island

A dynamic-island bar plugin for the Omarchy shell (Quickshell 0.3.2, Hyprland 0.56).
One pill, top-centre, that morphs between idle, hover, widget and HUD forms.

Status: all four milestones done and live (see "Verified" and "Not verified" below).

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

## Install
```
python3 deploy.py            # copies the bar and the OSD bridge into ~/.config/omarchy/plugins
omarchy plugin enable io.github.aicyraa.island
omarchy plugin enable io.github.aicyraa.island-osd   # optional: volume/brightness popups become the island HUD
```
From git: `omarchy plugin add <git-url> --enable` installs the bar alone. The OSD bridge lives in `osd/`
and is a second plugin (one repo = one plugin for `plugin add`), so copy it with `deploy.py`.
Enabling the bridge disables stock `omarchy.osd` automatically, so there is only ever one OSD.

## Widgets
Each widget is `widgets/<Name>.qml`, registered in `widgets/Registry.js` (file, width, height).
`Island.qml` loads it through a `Loader` that is active only while the widget is on screen, so a closed
widget is destroyed together with its Timers and Processes (verified: 0 spawns after close).

| id            | what it shows |
|---------------|---------------|
| home          | quick settings: Wi-Fi, Bluetooth, Focus (DND), Night light, Stay awake, Dictation + volume and brightness sliders |
| wifi          | SSID, signal, band, IP, speed, network list (scans only while open) |
| bluetooth     | radio switch, known devices with battery, connect/disconnect |
| audio         | output and input sliders, device pickers |
| display       | brightness, night light, text size |
| battery       | charge, time left, draw, health, power profile, stay awake |
| calendar      | month grid, locale first weekday, ISO weeks, khal events if khal exists |
| worldclock    | zones from `~/.local/state/island/world-clock.json`, fuzzy add, system `date` for DST |
| power         | 1 Shutdown, 2 Reboot, 3 Sleep, 4 Lock, uptime, restart-needed badge, hibernate chip if supported |
| notifications | history (read from the shell's state files), Focus toggle, dismiss, replay |
| media         | MPRIS player, controls, progress |
| system        | CPU, memory, CPU temperature (never touches the discrete GPU) |
| tray          | status-notifier icons |
| theme         | theme cards with swatches and wallpaper preview, applies with `omarchy-theme-set` |
| weather       | temperature, condition, high/low (one request to wttr.in per open) |
| agent         | AI-agent usage limits close to their cap (reads Omarchy's usage files) |

### Conventions every widget follows
- Esc closes (a widget can claim Esc for a sub-mode with `capturesEscape`), `?` shows the widget's `hint` row.
- Number keys pick tiles (1-6 Home, 1-4 Power, 1-3 Battery); arrows move; Enter activates.
- Show `No adapter` / `Nothing playing` / loading / error states, never a blank panel; hide a control whose hardware is absent.
- Plain text only (`textFormat: Text.PlainText`) for anything that comes from outside (SSIDs, titles, notifications).

### Idle pill actions
Scroll the volume icon to change volume (middle click mutes, click opens Audio); scroll the sun (hover form) for brightness;
click the clock for the calendar; scroll the workspaces to switch; click Wi-Fi / battery to open them. Indicators
(recording with timer, Focus, night light, stay awake, update, dictation) appear only while active and clicking one runs its action.
Indicator state is refreshed on events (startup, widget open/close, `omarchy-shell omarchy.indicators refresh`), not by polling.

### How to add a widget
1. Create `widgets/MyThing.qml`: an `Item` with `focus: true`, a `hint` string, and a `Keys.onPressed` handler.
2. Add `mything: { file: "MyThing.qml", w: 460, h: 260 }` to `widgets/Registry.js`.
3. Add `"mything"` to the shortcut list in `Bar.qml` and bind a key to `hl.dsp.global("island:mything")`.
4. Colours only from `Theme`, durations through `IslandState.reducedMotion`, processes inside the widget (they die with it).

## Keybinds (old to new)
Added to `~/.config/hypr/bindings.lua` between `>>> io.github.aicyraa.island` markers. Old control-center lines removed.

| key (SUPER + CTRL + ...) | was | now |
|---|---|---|
| M | Control center | quick settings (home) |
| A | Control center: Sound | audio |
| B | Control center: Connect | bluetooth |
| W | Control center: Connect | Wi-Fi |
| N | Omarchy Network panel (`rebind`) | Wi-Fi |
| P | Control center: Power | battery and power profile |
| D | Control center: Power | display |
| ALT + D | Control center: Time | calendar |
| ALT + E | Elsewhen world clock (`rebind`) | world clock |
| Z | free | world clock |
| Q | free | power (shutdown, reboot, sleep, lock) |
| ALT + N | free | notifications |
| Y | free | media |
| U | free | system usage |
| G | free | tray |
| T and SHIFT + SPACE | Omarchy theme menu (`rebind`) | island theme picker |
| SHIFT + A | Omarchy Agent (`omarchy-agent --pick`) | Omarchy Agent, launches the default agent in a terminal (the island agent widget is on SUPER + ALT + A) |
| ALT + W | free | weather |
| ALT + ESCAPE | free | panic: `omarchy restart shell` |

`hl.unbind` is used before the keys the old control center bound; `o.rebind` replaces Omarchy defaults whose target
(a stock bar widget panel) no longer exists under the island. Original lines are in `bindings.lua.bak-island-*`.
The stock theme menu is still reachable through the root menu.

## Layer rule
`hl.layer_rule({ match = { namespace = "^aicyraa-island$" }, blur = true, ignore_alpha = 0.05, no_anim = true, animation = "none" })`
in `looknfeel.lua`: blur only where the pill is, and no compositor fade (the island animates itself).

## Privacy and network
Only the weather widget uses the network: one HTTPS request to wttr.in when it opens (10 s timeout, 64 KB cap, validated fields),
never repeated on its own. The update indicator runs `omarchy-update-available` at most every 30 minutes.

## Tuning notes: reduced motion
`omarchy-shell island reducedMotion true` sets every spring and fade to 0 and disables overshoot (persisted in
`~/.local/state/island/state.json`).

## Rollback
- Fast: `./rollback.sh` (re-enables `jee.bar` and stock OSD, disables the island, restarts the shell). One-liner without the script:
  `omarchy plugin disable io.github.aicyraa.island; omarchy plugin enable jee.bar; omarchy plugin enable omarchy.osd; omarchy restart shell`
- The host also falls back to the stock bar by itself if the island fails to load.
- Panic key: SUPER + CTRL + ALT + ESCAPE restarts the shell.
- Config backups: `~/.config/omarchy/shell.json.bak-island-*`, `~/.config/hypr/bindings.lua.bak-island-*`, `looknfeel.lua.bak-island-*`.
- The old control center is disabled, not deleted: `~/.config/omarchy/plugins/io.github.aicyraa.control-center.disabled`
  (backup copy in `~/.config/omarchy/backups/`, source in `~/Work/omarchy-control-center`).
  Restore: rename the folder back, `omarchy plugin enable io.github.aicyraa.control-center`.
- `omarchy restart shell` refuses while the screen is locked; unlock first.

## Verified
Rig and live: state machine under toggle storms, hover timing, widget A to B without idle, HUD priority, fullscreen hide and
explicit-widget override, Power keys (dry run), all 16 widgets open in the live shell with a clean log, three themes including a
light one, hex literals only in the `Theme.qml` fallback block, 0 child processes at idle, 0 spawns after a widget closes.

## Not verified
- Mouse: scroll/middle-click on pill icons, hold-to-confirm ring, click-outside (no way to inject mouse clicks here).
- Sleep, hibernate, shutdown, reboot, lock were only dry-run, never fired. Hibernate chip shows because Omarchy's own check passes.
- Second monitor (only one here); fullscreen hide uses the focused workspace, so on two monitors it may hide the wrong one.
- khal events (khal is not installed), bluetooth connect/disconnect, Wi-Fi connect, tray context menus (right click sends the secondary action only).
- "Restart needed" badge uses a limited check (running kernel's modules missing); Omarchy exposes no flag file.
- Spring values are tuned by eye on one screen; the Omarchy guide discourages bounce and over 300 ms, the island overrides that on purpose.
