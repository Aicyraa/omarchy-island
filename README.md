# Island

A dynamic-island bar plugin for the Omarchy shell (Quickshell 0.3.2, Hyprland 0.56).
One pill, top-centre, that morphs between idle, hover, widget and HUD forms.

Status: all four milestones done and live (see "Verified" and "Not verified" below).

## Architecture

```
Bar.qml          plugin entry (manifest kind "bar"): Variants -> one Island per screen,
                 IPC loaders, Hyprland global shortcuts, charger HUD, host bar contract
Island.qml       one PanelWindow per screen: fixed size, transparent, click-masked, holding the
                 animated `pill`; sizes the pill from the active widget's implicit size
State.qml        singleton "IslandState": the state machine (file is State.qml, the type is
                 IslandState because QtQuick already has a type called State)
Theme.qml        singleton: palette -> colour roles, contrast guard, and ALL layout tokens
services/        Net, Bt, Audio, Brightness, Power, Indicators, Notifs, Stats, Cmd (singletons)
components/      shared building blocks (below) + IdleForm (the idle/hover pill) + Workspaces
widgets/         one file per widget, each built on WidgetPanel; Registry.js lists them
ipc/             HostIpc (inside the shell) / PlainIpc (test rig) / indicator and bar handlers
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
system tray theme`. Bind with
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
| Pill shrinking (both)   | 6.0    | 0.55    | a bouncy spring shrinking toward a small target dips below it and re-expands, which clipped the icons and made the idle bar flash twice on close; this pair never undershoots (measured) and still settles in ~0.35 s |
| Workspace pill height | 4.5 | 0.30 | the focused workspace stretches UP into a 14px pill; the old one springs back down at the same time, so they overlap like a hand-over |
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

## Layout system (tokens, content-sized panels, shared components)

### Tokens (Theme.qml)
Everything that has a size comes from `Theme`, nothing is hard-coded in a widget.

| token | value | meaning |
|---|---|---|
| `s4 s8 s12 s16 s20` | 4 8 12 16 20 | spacing scale |
| `panelPadding` | 16 | ONE padding on all four sides of every panel (it used to be 14 to 24) |
| `rowGap` / `sectionGap` | 4 / 12 | between rows / between sections |
| `rowHeight` `sliderHeight` `tileHeight` | 44 44 56 | |
| `tileRadius` / `pillRadius` | 18 / Hyprland rounding + 4 | `pillRadius` matches the Compass menu |
| `panelMaxHeight` `panelMinHeight` `panelMaxWidth` | 420 48 720 | the fixed layer window is sized for these |
| `iconSm iconMd iconLg` | 16 20 24 | icon sizes |

Colour roles: `background surface surfaceRaised outline text textMuted accent accentText
textOnAccentMuted badgeText success warning danger`, plus the guarded `accentInk successInk
warningInk dangerInk` (use these for text, icons and lines; use the plain colours only for FILLS)
and `textOnWarning textOnDanger`. Every text role is nudged (`Theme.lift`) toward the text colour
just far enough to reach 4.5:1 on the pill, tiles and raised rows, instead of snapping to
black/white. `omarchy-shell island debug contrast` audits 21 pairs; all pass in 7 themes.

### Content-sized panels (the mechanism)
`WidgetPanel.qml` is the base of every widget. Children go in its inner column; its
`implicitHeight` is `content + 2*panelPadding`, clamped to `[panelMinHeight, panelMaxHeight]`.
`Island.qml` reads the loaded widget's `implicitWidth/implicitHeight` (`widgetSize()`), so the pill's
target size IS the content size, and the existing width-leads/height-follows spring retargets whenever it
changes (a list filling in, a zone being added). Until the widget is loaded, `Registry.js` supplies an
estimate for the first frames only. Taller content scrolls in a `Flickable` with a fade at each clipped
edge and a thin indicator; `reveal(item)` keeps the selected row in view. The scrolling area is inset 8px from the top and bottom of the pill, so rows are clipped before they touch the pill edge and the padding is visible even mid-scroll. Hidden sections (khal events,
the hibernate hint) take no space. A widget with nothing to show sets `compact: true` and becomes a small
toast (Tray with no icons).

The layer window is fixed (`panelMaxWidth + ears` by `panelMaxHeight + 20`). The click-through
`mask` is the `zone` item, which is exactly the pill's target size plus the 12px ears for a widget
(a few px more for idle/hover so moving into the expanded pill does not close it).

### Smooth widget switching
A swap runs in two beats (old fades out in 80 ms, then the new one fades in), with two rules that keep it clean:
the content is always laid out at the size of the widget that is actually on screen (`shownSize`, which lags the
pill's target by the fade-out), so an outgoing widget is never stretched or squeezed toward the incoming size; and a
**reveal gate** (`fit` in `Island.qml`) holds the incoming content back until the pill has nearly reached its size, so a
wider widget is not clipped by a still-small pill and the idle form does not sit at the top of a still-tall pill.
The gate only runs right after a swap (and times out after 500 ms), so a widget whose own content grows is never faded.
Hover is also suppressed while a widget is open (`hoverIntent` records the pointer but starts no timers), and closing a widget
returns straight to idle, so the expanded hover form can never flash on the way back.

### Shared components
`Icon` (one 24-grid stroke family), `WifiIcon` (fan with signal levels, used in the pill AND panels),
`VolumeIcon` (waves grow with level), `BatteryIcon`, `PillSlider` (icon inside the fill; value label, dimmed
and badge states, thin variant; also the HUD), `Tile` (number badge in a safe inset of 0.4 x radius),
`ListRow` (fixed height, content on the shared edge, highlight bleeds only 8px so 8px always remains to the pill edge), `IconButton`,
`Sparkline` (polyline + area fill), `WidgetPanel`.

### Debug overlay and measuring
```
omarchy-shell island debug layout      # toggle the overlay: pill (red), 16px inset (green), text (magenta), icons (cyan)
omarchy-shell island debug measure     # JSON: pill size, content blocks' padding on 4 sides, clock offset from centre
omarchy-shell island debug contrast    # JSON: every text/background pair with its ratio
omarchy-shell island debug hover-on|hover-off   # inject the pointer-over-pill event (test hook; real pointers cannot be scripted here)
```
`blocks` padding is the visual padding (the panel's rows/cards/tiles); `pad` is the ink padding.
All widgets measure `top = bottom = left = right = 16` (scrolling panels report no bottom).

## Widgets
Each widget is `widgets/<Name>.qml`, registered in `widgets/Registry.js` (file, width, height).
`Island.qml` loads it through a `Loader` that is active only while the widget is on screen, so a closed
widget is destroyed together with its Timers and Processes (verified: 0 spawns after close). The one exception is `services/Stats.qml`: a single 2 s timer reading three /proc files into a 60-sample ring buffer so the System charts are full on open. Measured cost: 0.30% of one core with it, 0.25% without (see README "Verified"); set `ISLAND_STATS_OFF=1` or `Stats.alwaysOn: false` for the fallback that samples only while the widget is open.

| id            | what it shows |
|---------------|---------------|
| home          | the hover form, pinned (profile header, icon-only quick toggles, volume and brightness, media player) |
| wifi          | SSID, signal, band, IP, speed, network list (scans only while open) |
| bluetooth     | radio switch, known devices with battery, connect/disconnect |
| audio         | Output and Input cards: mute button, level, active device, device list |
| display       | brightness, night light, text size |
| battery       | charge, time left, draw, health, power profile, stay awake |
| calendar      | month grid, Omarchy reminders (list, quick add, cancel), optional khal events |
| worldclock    | zones from `~/.local/state/island/world-clock.json`, fuzzy add, system `date` for DST |
| power         | shutdown, reboot, sleep, lock, plus battery, profile, updates, last boot, kernel, session |
| notifications | history (read from the shell's state files), Focus toggle, dismiss, replay |
| system        | CPU, memory, temperature charts; load, uptime, CPU clock, disk, swap, network rate; three busiest processes |
| tray          | status-notifier icons |
| theme         | ONE horizontal strip of theme cards (720 x ~188 px, scrolls sideways): wallpaper, name on a scrim in the theme's own colours, swatches, light/dark chip, check on the current theme; applies with `omarchy-theme-set` |
| weather       | temperature, condition icon (sun/moon/cloud/rain...), high/low; location auto by IP or `weatherLocation` in state.json |
| agent         | usage per agent: tokens today and over 7 days, 7-day bars, limits with reset times, output/input/cached tokens, prompts, sessions, top model |

### Conventions every widget follows
- Esc closes (a widget can claim Esc for a sub-mode with `capturesEscape`). There is no on-screen key guide; `hint` strings only document keys in the source.
- Number keys pick tiles (1-6 Home, 1-4 Power, 1-3 Battery); arrows move; Enter activates.
- Show `No adapter` / `Nothing playing` / loading / error states, never a blank panel; hide a control whose hardware is absent.
- Plain text only (`textFormat: Text.PlainText`) for anything that comes from outside (SSIDs, titles, notifications).

### Pill actions
Idle shows workspaces, the clock (exactly centred) and Wi-Fi + battery, plus an icon for any Omarchy
indicator that is on (recording with a timer, Focus, night light, stay awake, update, dictation).
Hovering for ~170 ms replaces the bar with a preview of the essentials (`components/HoverPreview.qml`): a profile header
(your avatar from `~/.face`, greeting, user, host and uptime, clock, battery, on top of the current wallpaper), five quick
toggles (Wi-Fi, Bluetooth, Focus, Night light, Awake; click toggles, right-click opens the full widget), volume and
brightness sliders, and, only while something is playing or paused with a track, a media player (`components/MediaCard.qml`):
the cover art as a lightly blurred background, controls, progress and a real spectrum visualizer from `cava`
(`assets/cava.conf`; it runs only while a track plays and the card is visible).

### How to add a widget
1. Create `widgets/MyThing.qml`: a `WidgetPanel` with `preferredWidth`, an optional `hint` string (documentation only) and a `Keys.onPressed` handler; put content inside it.
2. Add `mything: { file: "MyThing.qml", w: 460, h: 260 }` to `widgets/Registry.js` (w/h are only a first-frame estimate).
3. Add `"mything"` to the shortcut list in `Bar.qml` and bind a key to `hl.dsp.global("island:mything")`.
4. Sizes and colours only from `Theme` tokens, durations through `IslandState.reducedMotion`, processes inside the widget (they die with it). Use the `*Ink` colours for text/icons.

## Keybinds (old to new)
Added to `~/.config/hypr/bindings.lua` between `>>> io.github.aicyraa.island` markers. Old control-center lines removed.

| key (SUPER + CTRL + ...) | was | now |
|---|---|---|
| M | Control center | quick settings (home) |
| A | Control center: Sound | audio |
| B | Control center: Connect | bluetooth |
| W | Control center: Connect | Wi-Fi |
| N | Omarchy Network panel (`rebind`) | notifications |
| P | Control center: Power | battery and power profile |
| D | Control center: Power | display |
| ALT + D | Control center: Time | calendar |
| ALT + E | Elsewhen world clock (`rebind`) | world clock |
| Z | free | world clock |
| Q | free | power (shutdown, reboot, sleep, lock) |
| Y | free | U | free | system usage |
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
`~/.local/state/island/state.json`, together with `weatherLocation`).

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
Measured (rig, 3 themes unless noted; numbers and before/after images are in `~/Work/omarchy-island-ss`):
- every widget: padding top = bottom = left = right = 16 px (scrolling panels report no bottom); no child exceeds the pill
- idle and hover: clock centre within 0.7 px of the pill centre; hover top/bottom padding 8/9
- contrast: 21 text/background pairs, 0 below 4.5:1 in 7 themes (genesis, catppuccin-latte, flexoki-light, white, tokyo-night, gruvbox, nord)
- state machine under a toggle storm settles with 0 px error; the mask region equals the pill plus the 12 px ears
- 0 child processes at idle; 0 spawns after a widget closes; the one polling exception (System ring buffer) costs 0.30% of a core vs 0.25% without it
- all 16 widgets open in the live shell with a clean log; hex literals only in the `Theme.qml` fallback block

## Not verified
- Mouse: scroll/middle-click on pill icons, the hold-to-confirm ring, click-outside, and real click-through just outside the pill
  (no way to inject real pointer motion or clicks here; Hyprland's focus-follows-mouse ignores a warped cursor)
- Sleep, hibernate, shutdown, reboot, lock were only dry-run, never fired
- Second monitor (only one here); fullscreen hide uses the focused workspace, so on two monitors it may hide the wrong one
- khal events (not installed), Bluetooth connect/disconnect/scan, Wi-Fi connect, tray context menus (right click sends the secondary action only)
- "Restart needed" uses a limited check (running kernel's modules missing); Omarchy exposes no flag file
- Weather location "Ermita" comes from wttr.in's IP geolocation (it matches your Asia/Manila time zone); set `weatherLocation` in state.json to pin it
- Spring values are tuned by eye on one screen; Omarchy's guide discourages bounce and over 300 ms, the island overrides that on purpose
- Deploying a changed bar plugin needs `omarchy restart shell`; the running shell caches its QML

## Cover art fallback (privacy note)
Players that send no `mpris:artUrl` (a browser playing YouTube) get their cover from Apple's public iTunes Search API
(`services/ArtLookup.qml`). The artist and title text is sent once per distinct track, only while a media card is on screen;
results are cached for the session. Delete the `ArtLookup.request` calls in `components/MediaCard.qml` to turn it off.

## Type and colour (softer look)
- Weights: no Bold. `Theme.weightStrong` (DemiBold) for titles and big numbers, `Theme.weightLabel` (Medium) for small emphasised text, Normal otherwise (Adwaita Sans has real Medium/SemiBold cuts).
- Text on accent fills is the normal light text colour on `Theme.accentFill` (the accent deepened toward the pill until it reaches 4.5:1), not near-black on the raw accent.
- `Theme.pillBase` lifts a near-black theme background (luminance < 0.01) toward the surface colour so the pill is never pure black.

## Focus animation and scrollbar
- Moving the selection animates: `FocusRing` (tiles, sliders, icon buttons) springs in from slightly larger and fades out of the old item; list rows share ONE highlight background (`FocusTarget` + the panel's `hl` rectangle) that slides and resizes from the old row to the new one with a small overshoot. `reducedMotion` turns it all off.
- `Scroller` replaces the plain indicator: a slim pill, dim when idle (a cue that there is more), brighter and thicker while scrolling or hovered, accent while dragged; drag it, click the track to jump, or wheel over it.

## Cache and preloading
Widgets never open empty. `services/Cache.qml` is a small persisted store (`~/.local/state/island/cache.json`, loaded synchronously at startup); the data services restore from it and refresh in the background (stale-while-revalidate):
| service | data | refreshed |
|---|---|---|
| `Themes` | every theme (name, preview, colours), current theme; preview images decoded ahead of time | startup, hover, picker open |
| `SysInfo` | load, uptime, disk, swap, clock, network rate, busiest processes | startup, hover (if older than 5 s), every 3 s while the System widget is open |
| `AgentUsage` | per-agent usage | startup, hover (older than 60 s), widget open |
| `WeatherData` | wttr.in reading (one bounded request when older than 10 min) | startup, hover, widget open |
`services/Prefetch.qml` decides when: `start()` 2.5 s after the shell is up, `touch()` when the pointer reaches the island. The first-ever run has nothing cached (widgets then show their loading line once). Delete the cache file to reset.

## Staying open while the cursor is on it
The inactivity timer (12 s, 15 s for Power) does not rely on hover events alone: a cursor that sits still on the widget sends none. Before closing, `State.checkCursor()` asks Hyprland where the cursor is (`assets/cursorpos.sh`) and stays open, restarting the countdown, while it is over the widget. Typing also keeps it open (3 s after the last key).
Every close is logged with its reason (`qs log -p /usr/share/omarchy/shell | grep "widget closed"`): `Esc`, `idle timeout, cursor away`, `focus grab cleared, cursor away`, or `(explicit)` for a key press / IPC. The focus-grab path (another window took keyboard focus) is guarded the same way as the idle timeout: if the cursor is still on the widget it stays open and the grab is re-armed.
The hover form works the same way: when the pointer is reported gone, `closeTimer` confirms with the real cursor position (`State.probeCursor`) before collapsing, and re-arms while the cursor is still on the form. A hover close is logged as `island: hover closed, cursor away` (grep for `island: `).

## Bar status icons and the visualizer
- Status icons in the bar (recording, dictation, Focus, Night light, Awake, update) are scaled to the battery body's height like the Wi-Fi glyph (`Icon.matchBattery`, per-icon extents in `Icons.js`; the stroke is only partly compensated so small glyphs stay legible).
- While any MPRIS player is playing, a 7-bar audio visualizer (real `cava` data) springs out of the left edge of the clock; the pill widens only if it needs the room. cava runs only while a track plays and the idle form is showing. `ISLAND_FORCE_VIZ=1` forces it on for testing.
- Toggles (Focus, Night light, Awake) flip the visible state immediately and re-read it 450 ms later; a refresh requested while another is running is queued, not dropped.
