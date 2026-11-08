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
  property real hudValue: 0           // percent, 0..100
  property string hudMessage: ""      // text-only HUD (no progress bar) when set
  property bool notifActive: false
  property bool hoverOpen: false

  property string activeScreen: ""    // screen that owns widget/HUD/notification
  property string hoverScreen: ""     // screen showing the hover form
  property string pendingHoverScreen: ""
  property var hovered: ({})          // screenName -> true while pointer is over it
  readonly property bool pointerOver: Object.keys(hovered).length > 0
  property real lastKeyAt: 0

  // The stock "toggle bar" key (SUPER+SHIFT+SPACE) sets a flag file; the island honours it.
  property bool barHidden: false
  function syncHidden() { if (!hiddenProbe.running) hiddenProbe.running = true }
  Process {
    id: hiddenProbe
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: StdioCollector { onStreamFinished: root.barHidden = text.trim() === "yes" }
  }
  // Match the Hyprland corner rounding (read once), like the Compass menu does, so
  // the island and the menu share the same bottom-corner radius.
  property int cornerRadius: 16
  Process {
    command: ["bash", "-c", "hyprctl getoption decoration:rounding -j | jq -r '.int'"]
    running: true
    stdout: StdioCollector { onStreamFinished: { var n = parseInt(text.trim()); if (!isNaN(n) && n >= 0) root.cornerRadius = n } }
  }
  // ---- debug (UI checking only; nothing runs unless switched on) ----
  property bool debugLayout: false
  property bool debugTrace: false      // logs the reveal state every 16 ms (animation debugging)
  property string measureResult: "{}"
  signal measureRequested()
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

  // The Omarchy screensaver is a window with app id org.omarchy.screensaver on every monitor.
  // While one exists the island stays hidden, even for widgets.
  readonly property bool screensaver: {
    var t = ToplevelManager.toplevels.values
    for (var i = 0; i < t.length; i++)
      if (t[i].appId === "org.omarchy.screensaver") return true
    return false
  }

  function focusedScreenName() {
    return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
  }

  // ---- hover intent: open after 170ms, close after 380ms ----
  function hoverIntent(over, screenName) {
    var h = Object.assign({}, hovered)   // reassign, so bindings notice
    if (over) h[screenName] = true; else delete h[screenName]
    hovered = h
    // A widget outranks hover. While one is open, remember where the pointer is but do NOT run the hover
    // timers: otherwise hoverOpen would turn true underneath the widget and the expanded form would flash
    // when the widget closes.
    if (widgetName !== "") return
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
  function closeWidget(reason) {
    if (widgetName === "") return
    console.warn("island: widget closed:", widgetName, reason || "(explicit)")
    widgetName = ""
    idleTimer.stop()
    // Straight back to idle. Hover does not resume by itself, so the pill never flashes its expanded form
    // on the way back; moving the pointer off and onto it again opens hover as usual.
    openTimer.stop(); closeTimer.stop(); hoverOpen = false
  }
  // Called on any input inside a widget; resets the inactivity countdown.
  function touch(isKey) {
    if (isKey) lastKeyAt = Date.now()
    if (widgetName !== "") idleTimer.restart()
  }
  function timeoutFor(name) { return name === "power" ? 15000 : 12000 }

  // ---- HUD: transient indicator, ~1.5s ----
  // message !== "" -> text-only HUD; otherwise a progress bar at `value` percent.
  function showHud(kind, value, message, ms) {
    if (widgetName !== "") return        // lower priority never interrupts higher
    hudKind = kind; hudValue = value; hudMessage = message || ""
    hudTimer.interval = ms > 0 ? ms : 1500
    activeScreen = focusedScreenName()
    hudActive = true
    hudTimer.restart()
  }
  // Human label for an OSD icon key ("volume-high" -> "Volume"). Real icons
  // replace this in milestone 3.
  function hudLabel(kind) {
    var k = String(kind || "").toLowerCase()
    if (k.indexOf("volume") === 0 || k === "mute") return "Volume"
    if (k.indexOf("micro") === 0 || k.indexOf("mic") === 0) return "Mic"
    if (k === "brightness" || k === "display") return "Brightness"
    if (k === "keyboard") return "Keyboard"
    if (k === "charger") return "Power"
    return k.length ? k.charAt(0).toUpperCase() + k.slice(1) : ""
  }

  // Payload as built by Omarchy's `omarchy-osd`:
  //   {icon, message, value, max, progressText, duration}  (all strings)
  // so the stock volume/brightness/etc. callers keep working unchanged.
  function showHudPayload(json) {
    try {
      var p = JSON.parse(json || "{}")
      var max = Math.max(1, parseInt(p.max || "100", 10))
      var v = parseInt(p.value || "0", 10)
      var hasProgress = p.value !== undefined && p.value !== "" && !isNaN(v) && !p.message
      var pct = hasProgress ? Math.max(0, Math.min(100, v * 100 / max)) : 0
      showHud(String(p.icon || ""), pct, hasProgress ? "" : String(p.message || ""),
              parseInt(p.duration || "1500", 10))
    } catch (e) { console.warn("island: bad HUD payload", e) }
  }

  // Timers exist but only RUN when started, so nothing ticks while idle.
  Timer { id: openTimer; interval: 170
    onTriggered: { root.hoverScreen = root.pendingHoverScreen; root.hoverOpen = true } }
  Timer { id: closeTimer; interval: 380
    // The pointer was reported gone. Confirm with the real cursor position before collapsing the hover form.
    onTriggered: root.probeCursor(root.hoverScreen, function (inside, raw) {
      if (inside) closeTimer.restart()
      else { console.warn("island: hover closed, cursor away (" + raw + ")"); root.hoverOpen = false } }) }
  Timer { id: hudTimer; interval: 1500; onTriggered: root.hudActive = false }
  Timer { id: idleTimer
    interval: root.timeoutFor(root.widgetName)
    onTriggered: {
      // Paused (re-armed) while the cursor is over the pill or a key was
      // pressed in the last 3s.
      if (root.pointerOver || Date.now() - root.lastKeyAt < 3000) restart()
      else root.checkCursor()
    } }

  // A cursor that sits still on the pill sends no hover events, so `pointerOver` can be false while it is right
  // there. Before closing for inactivity, ask Hyprland where the cursor really is; if it is on the widget, stay open.
  property var islands: ({})              // screen name -> its Island window (registered by Island.qml)
  // probeCursor(screen, cb): asks Hyprland where the cursor really is; cb(inside, raw) with inside = true when it is on
  // that screen's island (pill plus ears, 6 px of slack). Hover events can be lost or reported late; this is the ground
  // truth. Two checks can overlap (the idle timer, a focus-grab clear and the hover check): the second one now WAITS for
  // the running probe and gets its answer, instead of answering "outside" and closing the widget.
  function probeCursor(screen, cb) {
    var isl = islands[screen]
    if (!isl) { cb(false, "no island"); return }
    if (cursorProbe.running) { cursorProbe.waiting.push(cb); return }
    cursorProbe.box = isl.pillBox()
    cursorProbe.waiting = [cb]
    cursorProbe.raw = ""
    cursorProbe.command = ["bash", Qt.resolvedUrl("assets/cursorpos.sh").toString().replace("file://", ""), screen]
    cursorProbe.running = true
  }
  // guard(reason, done): the widget is about to close for `reason`. If the cursor is on the widget it stays open
  // (and the inactivity countdown restarts); otherwise it closes. `done(stayed)` is optional.
  function guard(reason, done) {
    if (widgetName === "") { if (done) done(false); return }
    probeCursor(activeScreen, function (inside, raw) {
      if (inside && widgetName !== "") { idleTimer.restart(); if (done) done(true) }
      else { closeWidget(reason + ", cursor away (" + raw + ")"); if (done) done(false) }
    })
  }
  function checkCursor() { guard("idle timeout") }
  Process {
    id: cursorProbe
    property size box: Qt.size(0, 0)
    property var waiting: []
    property string raw: ""
    function finish(inside) {
      var list = waiting; waiting = []
      for (var i = 0; i < list.length; i++) list[i](inside, raw)
    }
    stdout: StdioCollector { onStreamFinished: {
      cursorProbe.raw = text.trim()
      var p = cursorProbe.raw.split(" ").map(Number)
      cursorProbe.finish(p.length === 3 && !p.some(isNaN)
        && Math.abs(p[0] - p[2] / 2) <= cursorProbe.box.width / 2 + 6 && p[1] >= 0 && p[1] <= cursorProbe.box.height + 6)
    } }
    onExited: function (code) { if (code !== 0) { cursorProbe.raw = "probe failed " + code; finish(false) } }
  }

  // ---- persistence: ~/.local/state/island/state.json ----
  // One small JSON file: the reduced-motion flag and the optional weather location override ("" = auto-detect by IP).
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/island"
  property bool ready: false
  property string weatherLocation: ""
  FileView {
    id: store
    path: root.stateDir + "/state.json"
    onLoaded: {
      try {
        var j = JSON.parse(text())
        root.reducedMotion = !!j.reducedMotion
        if (typeof j.weatherLocation === "string") root.weatherLocation = j.weatherLocation.slice(0, 80)
      } catch (e) {}
      root.ready = true
    }
    onLoadFailed: root.ready = true
  }
  Process { id: mkdir; command: ["mkdir", "-p", root.stateDir]; running: true }
  function save() {
    if (!ready) return
    store.setText(JSON.stringify({ reducedMotion: reducedMotion, weatherLocation: weatherLocation }, null, 2))
  }
  onReducedMotionChanged: save()
}
