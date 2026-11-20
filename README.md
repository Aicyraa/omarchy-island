# Island

A dynamic-island bar plugin for the Omarchy shell (Quickshell 0.3.2, Hyprland 0.56).
One pill, top-centre, that stays docked while idle, detaches into a floating capsule when opened, and morphs between idle, hover, widget, notification toast, and HUD forms.

Status: all four milestones done and live, with floating detached widget transitions, asymmetrical Apple-inspired widget layouts, and companion OSD, menu, and headless notification bridges.

## Architecture

```
Bar.qml              plugin entry (manifest kind "bar"): Variants -> one Island per screen,
                     IPC loaders, Hyprland global shortcuts, charger HUD, host bar contract
Island.qml           one PanelWindow per screen: fixed size, transparent, click-masked, holding the
                     animated `pill`; sizes the pill from the active widget's implicit size
State.qml            singleton "IslandState": the state machine (file is State.qml, the type is
                     IslandState because QtQuick already has a type called State)
Theme.qml            singleton: palette -> colour roles, contrast guard, and ALL layout tokens
services/            Net, Bt, Audio, Brightness, Power, Indicators, Notifs, Stats, SysInfo,
                     Themes, WeatherData, AgentUsage, Cache, Prefetch, Cmd (singletons)
components/          shared building blocks + IdleForm (the idle/opening time capsule) +
                     HoverPreview + Workspaces + ClickCatcher
widgets/             one file per widget, each built on WidgetPanel; Registry.js lists them
ipc/                 HostIpc (inside the shell) / PlainIpc (test rig) / indicator and bar handlers
osd/                 companion plugin that routes Omarchy's OSD calls to the island HUD
menu-shim/           companion plugin that routes Omarchy's root menu to the island menu widget
notifications-shim/  companion headless notification service (`clonedFrom: omarchy.notifications`)
                     that keeps D-Bus, history, Focus mode, and IPC active while suppressing stock
                     top-right toast windows
rig.qml              run the island beside your live bar: `qs -p rig.qml`
```

### Why the window never resizes
Resizing a layer-shell window makes the compositor reconfigure the surface on every
frame, which stutters. So the window is a fixed size (`Theme.windowWidth` × `Theme.windowHeight`),
transparent, and `mask: Region { item: zone; ... }` makes everything outside the pill and side
capsules click-through. Only the inner `pill` Rectangle animates. `exclusiveZone` is the
collapsed idle height (`26 px`), so tiled windows don't jump when the pill grows over them.

## The state machine (State.qml)

Layered flags, each written only by its own functions:

| Layer        | Set by                         | Cleared by                                 |
|--------------|--------------------------------|--------------------------------------------|
| opening      | `beginOpening` (from idle only)| 150 ms detach timer or `cancelOpening`     |
| widget       | `openWidget` / `toggleWidget`  | Esc, click outside, same key, inactivity   |
| HUD          | `showHud` / `showHudPayload`   | 1.5 s timer                                |
| notification | `Notifs` `arrived` (`live.json`) | 4.5 s per toast, queue of 6, pauses while hovered or outranked |
| hover        | pointer over pill 170 ms       | pointer away 380 ms (verified via cursor probe) |

`mode` is **derived**, never assigned: `opening > widget > hud > notification > hover > idle`.
A lower layer can change its flag at any time, but `mode` keeps showing the higher one, and
when the higher layer ends `mode` falls back to whatever is still active.

### Detached opening transition
- **From idle**: opening a widget (or hover preview) first detaches the idle time capsule from
  the top edge (concave top ears fade out, top corners round into a floating capsule, and `y`
  drops down `12 px` over `150 ms`), then morphs smoothly from that floating capsule into the
  **detached floating widget** (rounded on all four corners, subtle hairline border, no top ears).
- **Widget-to-widget switch**: opening widget B while widget A is already open (or while the
  detached hover preview is open) checks `widgetName !== ""` / `hoverOpen`, skips the detach
  phase completely, and morphs A straight into B in place.
- **`reducedMotion`**: bypasses the opening phase and sets all springs and fade durations to `0`.

Notification toasts (`State.showNotif`, `components/NotifToast.qml`): every notification written
to `live.json` is announced once (silenced ones under Focus go straight to `history.json`).
Each shows its thumbnail (`components/NotifThumb.qml`), summary and body with a drain bar, and
waits its turn in a queue of six. Clicking opens the Notifications widget; `C` clears them.

## Keybinds

Added to `~/.config/hypr/bindings.lua` between `>>> io.github.aicyraa.island` markers.

| Key (`SUPER + CTRL + ...`) | Widget / Action |
|---|---|
| `M` | Quick settings (Home) |
| `A` | Audio (devices + 0–150% output/input sliders) |
| `B` | Bluetooth (auto-discover + connected device hero + hover disconnect) |
| `W` | Wi-Fi (auto-scan + connection metrics + QR share) |
| `N` | Notifications (Focus toggle + clear all + per-item remove) |
| `P` | Battery & power profile |
| `D` | Display (brightness, night light, text size, hardware toggles) |
| `ALT + D` | Calendar & quick reminders |
| `ALT + E` | World Clock (single binding; duplicate `Z` removed) |
| `Q` | Power (6 square actions: Lock, Sleep, Screensaver, Reboot, Shutdown, Logout) |
| `U` | System usage (`SUPER + CTRL + U`; there is no `Y` binding) |
| `G` | Tray (StatusNotifierItem app icons) |
| `T` and `SHIFT + SPACE` | Theme Picker (instant keyboard search + smooth strip) |
| `SHIFT + A` | Omarchy Agent (launches the default agent in a terminal) |
| `ALT + W` | Weather |
| `SUPER + ALT + A` | Agent Usage (active & default harness detection, e.g. OpenCode, Antigravity) |

### What does Tray (`SUPER + CTRL + G`) do?
Because the Island replaces a full-width taskbar that normally shows a permanent system tray,
the **Tray** widget hosts **StatusNotifierItem** icons exported by background desktop apps
(VPN clients, Discord, Slack, Spotify, Steam, clipboard managers, Syncthing, etc.).
Left-click (or `Enter`) activates an item; right-click (or `M`) sends its secondary
action/context-menu request; arrow keys navigate the grid. When no apps export tray icons, it
collapses to a compact `"No tray icons"` toast.

Hyprland global shortcuts (zero process spawn per keypress) are registered as `island:<widget>`:
`home wifi bluetooth audio display battery calendar worldclock power notifications system tray theme weather agent`.
Bind with `o.bind("SUPER + CTRL + Q", "Power", hl.dsp.global("island:power"))`.

## Driving it

```bash
omarchy-shell island toggle power        # inside the shell (fast socket path)
omarchy-shell island hud volume 60
omarchy-shell island hudJson '{"icon":"volume-high","value":"60","max":"100"}'
omarchy-shell island reducedMotion true
omarchy-shell island mode
```

## Theming & Asymmetrical Design Language

`Theme.qml` reads `~/.local/state/omarchy/current/theme/colors.toml` and maps it to semantic
roles (`background`, `surface`, `surfaceRaised`, `outline`, `text`, `textMuted`, `accent`,
`accentFill`, `accentText`, `accentInk`, `successInk`, `warningInk`, `dangerInk`,
`textOnWarning`, `textOnDanger`, `textOnAccentMuted`, `badgeText`, `pillBase`, `pill`).
A WCAG contrast guard (`Theme.readable` / `Theme.lift`) ensures every text/background pair
meets >= 4.5:1 on any light or dark theme and cross-fades over 250 ms on theme switches.

Widgets follow an **asymmetrical Apple-inspired layout**: a dominant focal card (~56–64%)
paired with an offset supporting column (~36–44%) rather than uniform grids of identical boxes,
while keeping shared `Theme.qml` tokens, pill geometry, and keyboard focus rings consistent.

## Tuning cheat sheet (springs)

| What | spring | damping | Why |
|---|---|---|---|
| Pill vertical detach (`y`) | 5.2 | 0.48 | crisp drop to `y = 12 px` with subtle settle |
| Pill width (growing) | 3.4 | 0.34 | leads; light overshoot reads as springy |
| Pill height (growing) | 3.0 | 0.36 | follows 40 ms later and slightly softer |
| Pill shrinking (both) | 6.0 | 0.55 | stiffer collapse prevents undershooting the 26 px idle bar |
| Theme strip scroll (`contentX`) | 4.8 | 0.52 | glides smoothly across fixed-slot cards without jitter at list ends |
| Battery profile pill (`x`) | 5.0 | 0.48 | snappy segmented-control handoff |

`reducedMotion` turns every spring off and sets all durations to `0`.

## Layout system (tokens, content-sized panels, shared components)

### Tokens (`Theme.qml`)
| Token | Value | Meaning |
|---|---|---|
| `s4 s8 s12 s16 s20` | 4 8 12 16 20 | spacing scale |
| `panelPadding` | 16 | uniform padding on all four sides of every panel |
| `rowGap` / `sectionGap` | 4 / 12 | between rows / between sections |
| `rowHeight` `sliderHeight` `tileHeight` | 48 44 56 | standard control heights |
| `typeCaption` `typeLabel` `typeBody` `typeTitle` `typeValue` | 10 11 12 14 26 | shared type scale |
| `tileRadius` `radiusChip` `pillRadius` | 18 / 10 / Hyprland rounding + 4 | shared corner radii |
| `panelMaxHeight` `panelMinHeight` `panelMaxWidth` | 470 48 720 | fixed layer window bounds |

### Content-sized panels & smooth switching
- `WidgetPanel.qml` sizes each widget to `content + 2 * panelPadding` (clamped to `[panelMinHeight, panelMaxHeight]`).
  Long content scrolls inside an inset `Flickable` with edge fades and `Scroller`.
- Widgets can opt out of cached-height reservation (`useReserve: false`, used by `Wifi.qml` and `Bluetooth.qml`)
  so post-boot discovery never holds phantom height that collapses later.
- Typing widgets (`ThemePicker`, `WorldClock` search) expose `wantsKeyboard: true` and `initialFocus`,
  granting `WlrKeyboardFocus.Exclusive` while open so typing works immediately without clicking first.
- A two-beat crossfade + reveal gate (`fit` in `Island.qml`) keeps outgoing widgets at their own
  `shownSize` during swaps and waits until the pill fits before revealing incoming content.

### Debug overlay & measuring
```bash
omarchy-shell island debug layout      # overlay: pill (red), 16px inset (green), text (magenta), icons (cyan)
omarchy-shell island debug measure     # JSON: pill size, content/block padding, overflow count, clock offset
omarchy-shell island debug contrast    # JSON: 21 text/background pairs with WCAG contrast ratios
omarchy-shell island debug hover-on|hover-off
```

## Widget highlights

- **Home (`HoverPreview`)**: Compact typography on Wi-Fi & Bluetooth tiles, live media card, 0–150% volume slider, and brightness slider.
- **Audio**: Asymmetrical Output (56%) / Input (44%) cards; device lists sit **above** the sliders; PipeWire software volume runs up to **150%** with a 100% unity marker and boost tint above 100%.
- **Bluetooth**: Auto-discovers on open so available devices render immediately; asymmetrical connected-device hero card at the top (type icon, status, MAC, battery, quick disconnect); zero restart icons; non-flickering hover disconnect (`unlink`) button on connected rows.
- **Wi-Fi**: Both circular restart/refresh buttons removed (auto-scans on open, `R` rescans, Power + QR kept); `useReserve: false` eliminates post-reboot height snapping; asymmetrical IP + Signal/Band/Link metric chips refresh silently without flickering.
- **Notifications**: Zero bottom divider lines per item; top-right **Clear** button and per-item hover **`×`** remove buttons; paired with `io.github.aicyraa.island-notifications` to suppress stock top-right toast windows cleanly while keeping D-Bus, history, Focus mode, and IPC intact.
- **Battery**: Asymmetrical hero percentage + animated charge bar + stacked Wattage/Health cards + unified segmented Saver/Balanced/Performance dock.
- **Display**: Asymmetrical Brightness hero card + offset Night Light card + Text Size stepper + conditional 2-column hardware switches.
- **Calendar**: Asymmetrical month grid (58%) + Selected Day hero & quick Reminders column (42%).
- **World Clock**: Vertically centered globe hero card + non-overlapping city rows + keyboard-editable timezone search.
- **Power**: Only the 6 compact square controls (Lock, Sleep, Screensaver, Reboot, Shutdown, Logout) in a flexible `Flow`, with no bottom subtitle text or system stats section.
- **Theme Picker**: Immediate keyboard search (`TextInput` with clear button), auto-sized `Current` badge + accent ring, and fixed-slot GPU-scaled cards for smooth animation even on the final theme.
- **Agent Usage**: Detects the configured default harness (`~/.config/omarchy/defaults/agent`) and live running harnesses (`opencode`, `agy`, `claude`, `codex`, etc.), rendering quota bars for limit-tracked agents and model/token/session breakdowns for local-stats harnesses like OpenCode.

## Installation

```bash
python3 deploy.py                                           # copies bar + OSD + menu + notifications bridges
omarchy plugin enable io.github.aicyraa.island
omarchy plugin enable io.github.aicyraa.island-osd          # optional: route volume/brightness OSD to island HUD
omarchy plugin enable io.github.aicyraa.island-menu         # optional: route root menu to island
omarchy plugin enable io.github.aicyraa.island-notifications # optional: suppress stock top-right notification toasts
omarchy restart shell
```

Enabling any companion bridge (`island-osd`, `island-menu`, `island-notifications`) automatically
disables its stock Omarchy counterpart via `clonedFrom` and restores it if disabled.

### Uninstall

```bash
omarchy plugin disable io.github.aicyraa.island-notifications
omarchy plugin disable io.github.aicyraa.island-menu
omarchy plugin disable io.github.aicyraa.island-osd
omarchy plugin disable io.github.aicyraa.island
# then remove the copied directories from ~/.config/omarchy/plugins/
omarchy restart shell
```

## Layer rule

`hl.layer_rule({ match = { namespace = "^aicyraa-island$" }, blur = true, ignore_alpha = 0.05, no_anim = true, animation = "none" })`
in `~/.config/hypr/looknfeel.lua`: blur only where the pill is, with no compositor fade (the island animates itself).

## Cache and preloading

`services/Cache.qml` (`~/.local/state/island/cache.json`) restores stale-while-revalidate data at startup:
| Service | Data | Refreshed |
|---|---|---|
| `Themes` | theme list, preview paths, palette colours, current theme | startup, hover, picker open |
| `SysInfo` | load, disk, swap, CPU clock, network rate, busiest processes | startup, hover, every 2.5 s while System is open |
| `AgentUsage` | per-agent usage, default & running harnesses | startup, hover, every 5 s while Agent is open (`R` forces full collect) |
