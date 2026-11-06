pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// State: the one brain of the island.
//
// Design: LAYERED FLAGS + DERIVED MODE, not a single `mode` variable we assign.
// Each layer (widget, hud, notification, hover) owns its own flag and only ever
// sets/clears ITS OWN flag. `mode` is a pure binding that picks the highest
// priority active layer:
//
//     user-opened widget > HUD > notification > hover > idle
//
// Because nothing assigns `mode` directly, rapid keybinds or hover flicker can't
// leave it in an impossible state: a lower layer can never interrupt a higher
// one (its flag changes, but mode keeps showing the higher layer), and when the
// higher layer ends, mode falls back to whatever is still active beneath it.
Singleton {
  id: root

  // ---- layers (each written only by its own functions below) ----
  property string widgetName: ""      // "" = no widget open
  property bool hudActive: false
  property string hudKind: ""
  property real hudValue: 0
  property bool notifActive: false
  property bool hoverOpen: false

  property string activeScreen: ""    // screen that owns widget/HUD/notification
  property string hoverScreen: ""     // screen showing the hover form
  property string pendingHoverScreen: ""
  property var hovered: ({})          // screenName -> true while pointer is over it
  readonly property bool pointerOver: Object.keys(hovered).length > 0
  property real lastKeyAt: 0

  property bool reducedMotion: false  // durations -> 0, no overshoot

  // ---- derived ----
  readonly property string mode:
    widgetName !== "" ? "widget"
    : hudActive ? "hud"
    : notifActive ? "notification"
    : hoverOpen ? "hover"
    : "idle"

  // What one screen should show. Widgets/HUD only appear on the owning
  // (focused) monitor; every other monitor stays idle.
  function modeFor(screenName) {
    if (mode === "idle") return "idle"
    if (mode === "hover") return screenName === hoverScreen ? "hover" : "idle"
    return screenName === activeScreen ? mode : "idle"
  }

  readonly property bool fullscreen:
    Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.hasFullscreen : false

  function focusedScreenName() {
    return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
  }

  // ---- hover intent: open after 120ms, close after 300ms ----
  function hoverIntent(over, screenName) {
    var h = Object.assign({}, hovered)   // reassign, so bindings notice
    if (over) h[screenName] = true; else delete h[screenName]
    hovered = h
    if (over) {
      if (hoverOpen) { if (screenName === hoverScreen) closeTimer.stop() }
      else { pendingHoverScreen = screenName; openTimer.restart() }
    } else {
      if (hoverOpen) { if (screenName === hoverScreen) closeTimer.restart() }
      else if (pendingHoverScreen === screenName) openTimer.stop()
    }
  }

  // ---- widgets ----
  function openWidget(name, screenName) {
    activeScreen = (screenName && screenName !== "") ? screenName : focusedScreenName()
    widgetName = name                    // A -> B swaps directly, never via idle
    openTimer.stop(); closeTimer.stop(); hoverOpen = false
    touch()
  }
  function toggleWidget(name, screenName) {
    if (widgetName === name) closeWidget(); else openWidget(name, screenName)
  }
  function closeWidget() {
    if (widgetName === "") return
    widgetName = ""
    idleTimer.stop()
    // Pointer still resting on the pill: bring the hover form back.
    var names = Object.keys(hovered)
    if (names.length > 0) { pendingHoverScreen = names[0]; openTimer.restart() }
  }
  // Called on any input inside a widget; resets the inactivity countdown.
  function touch(isKey) {
    if (isKey) lastKeyAt = Date.now()
    if (widgetName !== "") idleTimer.restart()
  }
  function timeoutFor(name) { return name === "power" ? 15000 : 12000 }

  // ---- HUD: transient indicator, ~1.5s ----
  function showHud(kind, value) {
    if (widgetName !== "") return        // lower priority never interrupts higher
    hudKind = kind; hudValue = value
    activeScreen = focusedScreenName()
    hudActive = true
    hudTimer.restart()
  }

  // Timers exist but only RUN when started, so nothing ticks while idle.
  Timer { id: openTimer; interval: 120
    onTriggered: { root.hoverScreen = root.pendingHoverScreen; root.hoverOpen = true } }
  Timer { id: closeTimer; interval: 300; onTriggered: root.hoverOpen = false }
  Timer { id: hudTimer; interval: 1500; onTriggered: root.hudActive = false }
  Timer { id: idleTimer
    interval: root.timeoutFor(root.widgetName)
    onTriggered: {
      // Paused (re-armed) while the cursor is over the pill or a key was
      // pressed in the last 3s.
      if (root.pointerOver || Date.now() - root.lastKeyAt < 3000) restart()
      else root.closeWidget()
    } }

  // ---- persistence: ~/.local/state/island/state.json ----
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/island"
  property bool ready: false
  FileView {
    id: store
    path: root.stateDir + "/state.json"
    onLoaded: {
      try { root.reducedMotion = !!JSON.parse(text()).reducedMotion } catch (e) {}
      root.ready = true
    }
    onLoadFailed: root.ready = true
  }
  Process { id: mkdir; command: ["mkdir", "-p", root.stateDir]; running: true }
  onReducedMotionChanged: {
    if (!ready) return
    store.setText(JSON.stringify({ reducedMotion: reducedMotion }))
  }
}
