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
| worldclock    | an interactive globe (drag to spin; real night side; your cities as dots; turns to the selected city) beside the clocks with 24 h strips |
| power         | shutdown, reboot, sleep, lock, plus battery, profile, updates, last boot, kernel, session |
| notifications | history as cards with a preview thumbnail: the image the notification is about (e.g. a screenshot, read from its file, nothing copied or cached on disk) or the app icon |
| system        | CPU, memory, temperature charts; load, uptime, CPU clock, disk, swap, network rate; three busiest processes |
| tray          | status-notifier icons |
| weather       | condition card (sky tint, big icon and temperature, High/Low) plus Feels like and Humidity |
| agent         | usage per agent, live: files re-read every 5 s while open, collectors run every 3 min (R forces), countdowns tick; tokens today and 7 days, limits, usage line |

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
Added to `~/.config/hypr/bindings.lua` between `>>> io.github.aicyraa.island` markers.

| key (SUPER + CTRL + ...) | was | now |
|---|---|---|
| M | Control center | quick settings (home) |
| A | Control center: Sound | audio |
| B | Control center: Connect | bluetooth |
| W | Control center: Connect | Wi-Fi |
| N | Omarchy Network panel (`rebind`) | notifications | history as cards with a preview thumbnail: the image the notification is about (e.g. a screenshot, read from its file, nothing copied or cached on disk) or the app icon |
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
| ALT + W | free | weather       | condition card (sky tint, big icon and temperature, High/Low) plus Feels like and Humidity |

`hl.unbind` is used before keys that earlier custom binds used; `o.rebind` replaces Omarchy defaults whose target
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

## Bar layout: three parts
- **Centre pill** (attached to the top edge, the one that morphs into widgets, the hover form and the HUD): the clock only.
- **Left capsule**: workspaces 1-5 are always shown as dots; workspaces beyond 5 that exist (or you are on) are appended, with a small "..." marker where the numbering skips (1 2 3 4 5 ... 8). The focused workspace is one short pill that glides between dots (its leading edge on a fast spring, the trailing edge on a slower one, so it stretches while travelling); new slots scale in. Test data: `ISLAND_FAKE_WS=1,2,3,8 ISLAND_FAKE_FOCUS=8`.
- **Right capsule**: the battery icon only (click opens the battery widget). No Wi-Fi icon and no status icons (Focus, Night light, Awake, dictation, update, **screen recording**) in the bar; they are in the hover form. The exception is a pulsing red dot in the right capsule while screen recording (click it to stop).
- The capsules (20 px tall) tuck 6 px under the pill's concave ears (the ears are drawn above them) and follow its springing edges, so they are pushed outward when the pill grows into a widget and slide back with it. The fixed window is `Theme.windowWidth` (1000) wide; clicks pass through everywhere except the pill zone and the two capsules.
- **Audio visualizer** (ported from the previous bar's clock widget): while a player is playing, five 2 px bars (cava, `assets/viz-bar.conf`, same 12 px / sqrt scaling and 320 ms slide-scale-fade entrance as before) appear on the left of the time and the pill makes room. cava runs only while a track plays and the idle form is showing. `ISLAND_FORCE_VIZ=1` forces it on for testing.
- Toggles (Focus, Night light, Awake) flip the visible state immediately and re-read it 450 ms later; a refresh requested while another is running is queued, not dropped.

## Transition timeline (what the pill does when a widget opens, switches or closes)
`omarchy-shell island debug trace` toggles a 16 ms log (`TRACE …` lines in `qs log`) of content opacity, fit, pill and target sizes. Measured after the smoothing pass: the old form fades out in 80 ms; the new content starts fading in as soon as the pill is ~10 % of the way to its height (growing: the top-anchored content is revealed by the pill) or within 3.2x of its size (shrinking), so the pill is never blank for more than ~50 ms (it used to be 150 ms on open and 250 ms on close). Grow springs are slightly better damped (0.34 / 0.36) and every widget's first-frame size estimate in `Registry.js` is its measured size, so the pill does not retarget when the real size arrives.

## Smooth edges
Every rounded shape in the bar is antialiased, and the Hyprland layer rule for the island uses `ignore_alpha = 0.9` (in `looknfeel.lua`): with the old 0.05 the compositor blurred the semi-transparent edge pixels as if they were solid, which made the capsule and pill outlines look stair-stepped. Now only the solid interior is blurred and the edge blends cleanly.

## The no-cover disc
When a track has no cover art (or it has not loaded yet) the media card shows `components/Vinyl.qml`: a black record with grooves, a label in the theme accent, a mark so the spin is visible, a fixed sheen, spinning while the track plays. (A drop shadow was tried and removed: it made the outlines look rough.)

## No snapping while data loads
A widget whose content arrives late (Wi-Fi networks, Bluetooth devices, the world clock, agents, weather, system details, themes) sets `dataLoading: true`. The island remembers each widget's height from the last time it was fully loaded (`Cache` key `wsize`) and uses it two ways: as the pill's size from the first frame, and as the widget's `reserve`. While loading, `WidgetPanel` keeps that height and fills the space the real content does not cover yet with pulsing placeholder rows, so the pill opens at its final size and the data just fills in. The reservation ends when loading ends (or after 2.5 s). Test: `ISLAND_FORCE_LOADING=1`. The rig and the live shell share the cache file.

## Theme picker search and selection
- Type to search: every typed character narrows the list to themes whose name contains those letters in order ("gru" finds Gruvbox). Backspace deletes; Esc clears the search first and closes the widget only when the search is empty. Enter applies the selected match. The header shows the search box and the position (for example "1 / 28").
- The selected card grows (12 % wider and larger, a spring) and its neighbours move aside to make room; the strip glides (a spring) so the selected card stays centred. No outline. Drag and wheel scrolling are not interrupted by the glide.

## Why widgets used to close, and the focus animation
- **Early close:** the cursor check that keeps a widget open answered "outside" whenever another check was already running. The idle timer, the focus-grab clear and the hover check can overlap, so a widget with the cursor on it could close. Overlapping checks now wait for the running one and get its answer. Close reasons include the raw cursor reading, e.g. `idle timeout, cursor away (683 120 1366)`.
- **Focus highlight:** the highlight used four separate springs (x, y, width, height), which moved unevenly. It is now one rectangle whose top and bottom edges move on their own clocks: the leading edge in 200 ms and the trailing edge in 320 ms, both with the same ease-out. A move that starts mid-flight begins from the current edges.
- **Selection ring:** a 200 ms ease-out tween instead of a spring, so it lands without wobbling.

## Keybind widgets stay open
A widget opened by its keybind (`island:<name>` global shortcut) is **pinned**: it stays open until Esc or the same keybind is pressed again. It ignores the inactivity timer and focus-grab closes, so moving the cursor away or focus moving to another window does not close it. Widgets opened from the bar or over IPC keep the old behavior (they close when the cursor is away for the idle timeout). A real click outside a pinned widget closes it: `components/ClickCatcher.qml` is a transparent full-screen layer that exists only while a pinned widget is open. It catches a complete click (press and release) that lands outside the island and closes the widget with the reason `click outside`. Its input region has a hole the size of the island's zone (`IslandState.zoneRects`), so clicks on the island and on the open widget go to the island, not the catcher. It ignores input for 300 ms after it appears, so the keypress that opened the widget cannot close it. While a pinned widget is open, clicks on the desktop are caught by the layer and do not reach the windows underneath (the same as a menu).

## Click catcher: the hole follows the drawn pill
The click catcher's hole covers the island's zone in screen coordinates. The zone is the larger of the target size and the pill as it is drawn right now, so it follows the spring frame by frame (a list that shrinks leaves the drawn pill briefly taller than its target). `omarchy-shell island debug zones` prints the hole. For every keybind widget the zone is the pill plus the 12 px ears, with the same height, centred on the screen.

## Menu core (milestone 2 of the menu merge)
`menu-core/` holds the menu model that the island's menu widget will use: a copy of Compass's `MenuModel.js` (pure JS, no QML dependencies) with `mergeMenuSources(defaults, user, hiddenPrefixes)`, which removes hidden sections from the items and the order. `menu-core/MenuHidden.js` lists the hidden prefixes (empty until the widgets that replace them land) and the routes that redirect to an island widget once hidden. Run the tests with `node menu-core/menu.test.js`; they include checks against the real stock menu file.

## Shared list highlight (milestone 3 of the menu merge)
The sliding highlight behind the rows moved out of `WidgetPanel` into `components/ListHighlight.qml` unchanged. It takes `host` (the panel, which provides `focusItem`), `container` (the scrolled content) and `content` (the column whose height change re-places it). Pixel check against the original, at rest on Notifications, Wi-Fi, Bluetooth and Theme: at a 5 % tolerance the images are identical, and the largest per-channel difference anywhere is about 4.7 %. Moving the selection still slides the highlight to the next row.

## The menu widget (milestone 4 of the menu merge)
- `services/MenuData.qml` (singleton): Omarchy's menu tree from the stock jsonc plus the user extension, minus the hidden sections (`menu-core/MenuHidden.js`), plus one `apps.<id>` row per installed desktop app. One read-only bash batch evaluates every `when:`, `checked:` and `disabled:` check; an installed app's Install row is hidden, as in Compass.
- `widgets/Menu.qml` (laid out like Compass): a search box with the item count; a fixed icon rail on the left (Home, then the top-level categories); the rows on the right. Home shows Recent (the most used apps and actions, ranked by frecency as Compass did; the first start imports Compass's usage file), Toggles (night light, stay awake, notifications) and About. Only the list scrolls: the rail and the search never move, and the list highlight moves in 110 ms. Type to search; Enter or Right opens a submenu or runs an action (the widget closes first); Left or Backspace goes up; Tab moves into the rail; Esc clears the search, goes up, then closes. Apps show their real icon. The old breadcrumb and the "Menu" label are gone.
- Not yet in this milestone: recents and frecency, the Tab rail focus, the dmenu mode, the summon routes and the shim plugin (milestones 5 and 7).
- Debug: `omarchy-shell island debug measure` reports the menu's route, rows and install-check counts in `widgetState`.
- Caveat: the install checks take about one second to run in the background, so right after startup a row can briefly show before its check result arrives.

## Menu requests and routes (milestone 5 of the menu merge)
- `omarchy-shell island openMenu '<json>'` opens the menu with the stock summon payload. A `menu` (or `initialMenu`) route opens that section (aliases resolve; an unknown route opens the top level; a route that is an action runs it). A route the island has replaced (see `menu-core/MenuHidden.js`) opens its island widget instead. A dmenu payload (`mode: select|input`, `options`, `prompt`, `selectionFile`, `doneFile`) opens the menu as a picker.
- dmenu answers: a choice writes the selection file (`<label>` or `<label>\t<detail>`) and then the done file; any other exit (Esc, closing, a click outside, a newer request) writes only the done file. The writes run through `Cmd.run` with positional arguments.
- `omarchy-shell island menuState` reports whether a request is open, its mode, the route and a revision counter. `menuRefresh` re-reads the menu tree.
- Not yet: the shim plugin that makes `omarchy-shell shell summon omarchy.menu` reach this widget (milestone 7), and the keyboard checks for the picker, which need a focused widget.

## Duplicate removal, step 1: Power replaces the menu's System section
- The Power widget now has the six System actions the menu had: Lock, Sleep, Screensaver, Logout, Reboot and Shutdown (Logout, Reboot and Shutdown need a hold or a second press).
- `menu-core/MenuHidden.js` hides `system` from the menu, and `system` and `power-menu` route to the Power widget. Hibernate stays on the H key when the machine supports it, as before (it has no tile).

## Duplicate removal, step 2: Home replaces the menu's Toggle section
- Home's hover form now has the six switches the menu's Trigger > Toggle had: Focus (silence notifications), Night light, Awake (stay awake), Dictation (when available), Screensaver and Crash capture. The last two read the toggle flags in `~/.local/state/omarchy/toggles`; the grid is three columns, so the form keeps its height.
- `menu-core/MenuHidden.js` hides `trigger.toggle`; the routes `toggle` and `toggles` open Home. A redirect now checks the stock section it stands for (`sourceId`), since an alias is gone from the tree once its section is hidden.

## Duplicate removal, step 3: Calendar replaces the menu's Reminder section
- Calendar already sets, lists and clears reminders (quick-add +5/+15/+30/+1 h, Custom, the list with cancel, and Clear all), so the menu's Reminder section (set, show, clear) is hidden. The routes `reminder` and `reminder-set` open Calendar.

## Duplicate removal, step 4: Wi-Fi shows the share code (the menu's Setup > Network > Wi-Fi QR)
- The Wi-Fi widget has a share button (QR icon, while connected). It runs `omarchy-network-qr --meta` and draws the code on a white card (dark modules, four-module quiet zone) in place of the network list; the password is only inside the code. Esc, the same button or Q goes back to the list.
- The menu's `setup.network.qr` section is hidden. The route `wifi-qr` opens Wi-Fi in share mode. The intent is taken once the network is connected, so it also works when the widget is created right after start.
- Left in the menu for now: DNS (Setup > Network > DNS) stays as it is, by request.

## Duplicate removal, step 5: restart buttons replace the menu's Update > Hardware (Wi-Fi, Bluetooth, Audio)
- Wi-Fi, Bluetooth and Audio each have a restart button (the restart icon). It runs `omarchy-restart-wifi`, `omarchy-restart-bluetooth` or `omarchy-restart-audio` directly, without the floating terminal the stock menu used. Audio's button is in a footer under the two cards.
- The menu's `update.hardware.wifi`, `update.hardware.bluetooth` and `update.hardware.audio` rows are hidden. Trackpad stays in the menu, since no island widget covers it.

## Duplicate removal, step 6: Display gets the hardware switches (the menu's Trigger > Hardware)
- Display has four more rows, each shown only when the machine has the device: Laptop display (on/off, laptops only), Mirror to external (laptops only), Touchpad and Touchscreen. They use the same helpers as the menu (`omarchy-hyprland-monitor-internal`, `omarchy-hyprland-monitor-internal-mirror`, `omarchy-toggle-touchpad`, `omarchy-toggle-touchscreen`) and read their state from the same flag files. Keys skip the rows a machine does not have.
- The menu hides only those four switches (eight ids: the `-on`/`-off` pairs). Hybrid GPU and touchpad haptics stay in Trigger > Hardware, since the island has no equivalent.

## Duplicate removal, step 7: Look (Background and Font) and the island theme picker replace Appearance > Theme, Background and Font
- New widget `widgets/Look.qml`: a Background section (Next, which cycles like `omarchy-theme-bg-next`, and the still images of the current theme, the current one checked; click or Enter sets it with `omarchy-theme-bg-set`) and a Font section (the monospace families from `omarchy-font-list`, the current one marked; click or Enter sets it with `omarchy-font-set`). Tab switches sections.
- The menu's `appearance.theme`, `appearance.background` and `appearance.font` are hidden. Their routes (`theme`, `themes`, `background`, `wallpaper`, `font` and the full ids) open ThemePicker or Look, on the matching section through `IslandState.intent`.
- Not copied: the stock image picker for backgrounds (Look lists the images without a picker and shows only still images; videos are left to Next).

## Cutover (milestone 7): the island's menu replaces Compass
- `menu-shim/` is the clone shim `io.github.aicyraa.island-menu` (`clonedFrom: omarchy.menu`, `keepLoaded`). Omarchy's summons and toggles of `omarchy.menu` (the Hyprland bindings, `omarchy-menu`, and the dmenu callers) reach it, and it forwards them to the island: `openMenu` with the same JSON, `closeMenu`, `menuRefresh`. `omarchy-shell menu ping|state|open|close|refresh` answers for it.
- The shell reads the shim's `opened` to choose between hiding and summoning. The island tells it when the menu or the widget it redirected to closes, for any reason (Esc, click outside, an action, the shell): `MenuData` sends `omarchy-shell -q menu closed` when the widget it opened goes away.
- `deploy.py` copies the shim too (`--no-menu` skips it).
- Compass (`io.github.aicyraa.compass-menu`) is disabled and still installed (milestone 8 removes it after a few days of use). The config was backed up to `~/.config/omarchy/shell.json.pre-island-menu.bak`. Rollback: `omarchy plugin disable io.github.aicyraa.island-menu && omarchy plugin enable io.github.aicyraa.compass-menu`, or put the backup back.
- Checked live: ping; toggle opens and closes; `system` redirects to Power; the island closing the menu clears the shim's state; a dmenu select cancelled by closing writes only the done file (no selection file); `omarchy-menu summon system`. Not checked: choosing an item in a dmenu list (Enter) and a real Esc press, since they need keyboard focus in the island.

## Menu improvements (after the Compass-style layout)
- Shortcut hints: an action row shows its Hyprland binding (read with `hyprctl binds -j`, matched by the binding's description, e.g. "Screenshot" shows Print).
- Pins: Ctrl+P pins or unpins the selected row; pinned rows head Home. Stored in the Cache.
- `/` scopes the search to the open category (`/ghost` searches only inside Apps when Apps is open).
- The last category is remembered for a menu opened without a route.
- Toggle states refresh every 3 s while the menu is open.
- The Install page's footer says how many installed apps the check hid.
- Hovering a rail item names it in the search row's right side.
- The active rail item has an accent bar; the footer lists the keys.
- Typed letters are bold in the matching rows (in order, fuzzy).
- Section labels (Recent, Toggles, Pinned) stick to the top while the list scrolls.
- Reduced motion turns off the rail colour fade and the highlight move.

## Look, step 1: no outlines, soft elevation shadows
- The pill and both capsules have no border. Instead they cast a soft shadow (`components/Elevation.qml`): eight rings, each a shape grown outward and cut out with the shape itself (even-odd), so nothing is painted under the translucent fill. The shadow falls 6 px down and reaches 22 px, peaking at about 27 % darkening at the edge.
- Capsules no longer tuck under the ears (`satTuck` 0), so nothing overlaps at the joins.
- Hyprland (`~/.config/hypr/looknfeel.lua`): the island layer's `ignore_alpha` is 0.5, so the translucent shadow is not blurred into a halo; the pill (alpha 0.70) still is.
