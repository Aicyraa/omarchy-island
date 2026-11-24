# Island

A dynamic-island bar plugin for the Omarchy shell (Quickshell, Hyprland) built on a Qt 6 module structure and the vendored `QuickshellDS` design system.
One floating obsidian capsule centered on the top (or bottom) edge that morphs smoothly between the idle TopBar, HUD, notification toast, Command Hub menu, and 18 redesigned widgets with a detached sibling `ScrollRail`.

## Architecture

```
Bar.qml                    thin Qt 6 bootstrap: Variants -> ClickCatcher + IslandWindow per screen,
                           IPC loaders, Hyprland global shortcuts, charger HUD
qml/
  QuickshellDS/            vendored design system (Theme, Primitives, Components, Patterns, Surfaces,
                           and 96 uniform 24x24 Lucide SVG icons in Assets/icons/)
  Core/                    ConfigStore (~/.config/omarchy/island-config.json), IslandState,
                           WidgetRegistry.js, WidgetSurface, IslandWindow, ClickCatcher, Visuals/
  Bar/                     TopBar, WorkspaceStrip, ActiveAppsStrip (event-driven, auto-hiding),
                           ClockCluster, AudioVizSlot (cava), BarIconButton, StatusEar
  Services/                ActiveApps, Audio, Brightness, Bt, Net, Power, Indicators, Notifs, Stats,
                           SysInfo, Themes, WeatherData, AgentUsage, ArtLookup, Cache, Cmd, MenuData
  Widgets/                 Settings (replaces Home), Media, Capture, Menu (6-tab Command Hub),
                           Wifi, Bluetooth, Audio, Display, System, Battery, Agent, Power,
                           Calendar, WorldClock, Weather, Notifications, ThemePicker, Look, Tray
  MenuCore/                MenuModel.js, MenuHidden.js, menu.test.js
  Ipc/                     HostIpc, PlainIpc, HostIndicatorsIpc, HostBarIpc
shims/
  osd/                     companion plugin routing Omarchy OSD calls to the island HUD
  menu/                    companion plugin routing Super+Space / omarchy-menu to Island Menu
  notifications/           headless notification bridge keeping D-Bus, history, and DND active
rig.qml                    standalone preview/test rig: `qs -p rig.qml`
```

### TopBar, Island Settings & Widget Suite
- **TopBar**: Floating `36 px` obsidian capsule (`Tokens.color.islandGround`) with workspace dots & gliding accent pill, auto-hiding animated active-workspace app strip (`ActiveAppsStrip`), stacked tabular clock/date (`HH mm` / `ddd d MMM`), weather chip, live `cava` audio visualizer slot (opens **Media**), connectivity/battery indicators, uniform 24×24 SVG widget strip (including **Capture** and **Clipboard**), and right-edge **StatusEar**.
- **Island Settings (`settings`)**: Replaces `home` (`home` remains an alias) with live-persisted `~/.config/omarchy/island-config.json` controls for surface material (`classic` / `glass` / `liquid`), corner radius strategy, density, UI scale, detached `ScrollRail` variant & side, bar edge (`top` / `bottom`) & pattern (`pill` / `notch` / `full`), topbar item visibility, menu mode (`morphed` / `spotlight`), and one-click presets.
- **Standalone Media (`media`) & Capture (`capture`)**: Dedicated MPRIS player with album art / spinning vinyl, scrub timeline, mirrored `cava` spectrum, and volume; plus screenshot delay/region/fullscreen/annotate, screen recording, OCR, QR, and color picker tools.
- **Omarchy Menu (`Super + Space`)**: Streamlined 6-tab Command Hub (`Home`, `Apps`, `Actions`, `Packages`, `Setup`, `Docs`) with fuzzy search, `/`-scoped filtering, `Keycap` hints, pins, and full `dmenu` compatibility.

### Why the window never resizes
Resizing a layer-shell window makes the compositor reconfigure the surface on every
frame, which stutters. So the window is a fixed size (`Theme.windowWidth` × `Theme.windowHeight`),
transparent, and `mask: Region { item: zone; ... }` makes everything outside the pill and side
capsules click-through. Only the inner `pill` container animates, backed by a hidden analytical `SmoothRect` (`Shape.CurveRenderer`) + `MultiEffect` drop shadow behind unlayered crisp text. `exclusiveZone` is computed from `topStripH - IslandState.gapsOut` (`22 px` for `gaps_out = 10`) so top and bottom topbar margins match equally (`6 px` above and below) and tiled windows never jump when the pill grows over them.

## The state machine (State.qml)

Layered flags, each written only by its own functions:

| Layer        | Set by                         | Cleared by                                 |
|--------------|--------------------------------|--------------------------------------------|
| widget       | `openWidget` / `toggleWidget`  | Esc, click outside, same key, inactivity   |
| HUD          | `showHud` / `showHudPayload`   | 1.5 s timer                                |
| notification | `Notifs` `arrived` (`live.json`) | 4.5 s per toast, queue of 6, pauses while hovered or outranked |
| hover        | pointer over pill 170 ms       | pointer away 380 ms (verified via cursor probe) |

`mode` is **derived**, never assigned: `widget > hud > notification > hover > idle`.
A lower layer can change its flag at any time, but `mode` keeps showing the higher one, and
when the higher layer ends `mode` falls back to whatever is still active.

### Single-fluid detach & morph transition + flanking capsules
- **From idle**: opening a widget (or hover preview) detaches the idle time pill cleanly off the
  top edge (`detachedOffset: 6 px`, concave top ears pull away, top corners round) and transforms
  directly into the **detached floating solid-black widget** (20 px analytical corners,
  `pillBorder` hairline, soft `MultiEffect` shadow) in one continuous motion.
  Meanwhile, the **Workspaces** capsule on the left and the compact status capsule (**Notifications**,
  **Bluetooth**, **Battery**, plus recording indicator) on the right stay aligned at
  `y = 6 px`, push outward beside the widget's top corners, and remain individually clickable
  through `ClickCatcher` holes without closing an open widget.
- **Widget-to-widget switch**: opening widget B while widget A (or hover) is already open keeps
  the pill detached in place and morphs A straight into B cleanly.
- **`reducedMotion`**: sets all springs and fade durations to `0`.

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
| Pill vertical detach (`y`) | 5.2 | 0.56 | crisp detach to `y = 6 px` without bouncing back to the top edge |
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
| `fontFamily` / `monoFamily` | `Adwaita Sans` / `JetBrainsMono Nerd Font` | native vertical-hinted typography (`components/Label.qml`, `Text.NativeRendering`) |
| `typeCaption` `typeLabel` `typeBody` `typeTitle` `typeValue` | 11 12 13 14 26 | shared type scale |
| `tileRadius` `radiusChip` `pillRadius` | 14 / 10 / max(20, rounding + 14) | analytical `SmoothRect` (`Shape.CurveRenderer`) corner radii |
| `panelMaxHeight` `panelMinHeight` `panelMaxWidth` | 470 48 720 | fixed layer window bounds (`windowWidth: 1080` for flanking capsules) |

### Content-sized panels, solid-black surfaces & smooth curves
- `WidgetPanel.qml` sizes each widget to `content + 2 * panelPadding` (clamped to `[panelMinHeight, panelMaxHeight]`) with **uniform 16 px padding on all four sides** (including scrolling edge clips and `Menu.qml`), and zero negative horizontal list-row highlight bleed (`ListHighlight.qml`, `ListRow.qml`, `Notifications.qml`).
- `SmoothRect.qml` uses `Shape` with `Shape.CurveRenderer` + `PathRectangle` for silky analytical curves across the pill, side capsules, buttons, slider fills, and cards without wrapping `Label` text in an offscreen FBO.
- `Island.qml` pairs opaque solid-black (`#000000`) `SmoothRect` backgrounds with `MultiEffect` drop shadows behind unlayered `Label` text.
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

- **Home (`HoverPreview`)**: Compact `490×336` layout with fading wallpaper header, live media card + 0–150% volume & brightness sliders on the left (`268 px`), and a staggered bento column on the right (`180 px`) with icon-disc Wi-Fi/Bluetooth cards, alternating wide/square daily toggles, and a segmented `Saver | Crash` bar.
- **Audio**: Asymmetrical Output (56%) / Input (44%) cards; device lists sit **above** the sliders; PipeWire software volume runs up to **150%** with boost tint above 100%.
- **Bluetooth**: Auto-discovers on open so available devices render immediately; asymmetrical connected-device hero card at the top (type icon, status, MAC, battery, quick disconnect); zero restart icons; non-flickering hover disconnect (`unlink`) button on connected rows.
- **Wi-Fi**: Both circular restart/refresh buttons removed (auto-scans on open, `R` rescans, Power + QR kept); `useReserve: false` eliminates post-reboot height snapping; asymmetrical IP + Signal/Band/Link metric chips refresh silently without flickering.
- **Notifications**: Zero bottom divider lines per item; top-right **Clear** button and per-item hover **`×`** remove buttons; paired with `io.github.aicyraa.island-notifications` to suppress stock top-right toast windows cleanly while keeping D-Bus, history, Focus mode, and IPC intact.
- **Battery**: Asymmetrical hero percentage + animated charge bar + stacked Wattage/Health cards + unified segmented Saver/Balanced/Performance dock.
- **Display**: Asymmetrical Brightness hero card + offset Night Light card + Text Size stepper + conditional 2-column hardware switches.
- **Calendar**: Asymmetrical month grid (58%) + Selected Day hero & quick Reminders column (42%).
- **World Clock**: Vertically centered globe hero card + non-overlapping city rows + keyboard-editable timezone search.
- **Power**: Only the 6 compact square controls (Lock, Sleep, Screensaver, Reboot, Shutdown, Logout) in a flexible `Flow`, with no bottom subtitle text or system stats section.
- **Theme Picker**: Immediate keyboard search (`TextInput` with clear button), auto-sized `Current` badge + accent ring, and fixed-slot GPU-scaled cards (`Text.QtRendering` inside scaled cards) for smooth animation even on the final theme.
- **System Usage**: Asymmetrical telemetry layout (`preferredWidth: 640`, fixed `innerW` math with zero overflow): dominant CPU hero card (58%) with clock/cores chip, uptime, state pill, and full-width chart; offset Memory & Temperature cards (42%) with sparklines; Disk / Load / Network / Swap `StatTile`s; and a Top Processes card with aligned tabular monospace columns.
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

`hl.layer_rule({ match = { namespace = "^aicyraa-island$" }, blur = false, no_anim = true, animation = "none" })`
in `~/.config/hypr/looknfeel.lua`: solid black opaque pill and shadow without compositor blur or fade (the island animates itself).

## Cache and preloading

`services/Cache.qml` (`~/.local/state/island/cache.json`) restores stale-while-revalidate data at startup:
| Service | Data | Refreshed |
|---|---|---|
| `Themes` | theme list, preview paths, palette colours, current theme | startup, hover, picker open |
| `SysInfo` | load, disk, swap, CPU clock, network rate, busiest processes | startup, hover, every 2.5 s while System is open |
| `AgentUsage` | per-agent usage, default & running harnesses | startup, hover, every 5 s while Agent is open (`R` forces full collect) |
