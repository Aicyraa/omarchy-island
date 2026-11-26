pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../Services"

// IslandState: layered-flag brain of Omarchy Island.
// Priority: widget > hud > notification > idle.
Singleton {
  id: root

  property string widgetName: ""
  property bool hudActive: false
  property string hudKind: ""
  property real hudValue: 0
  property string hudMessage: ""
  property bool notifActive: false

  property string activeScreen: ""
  property var hovered: ({})
  readonly property bool pointerOver: Object.keys(hovered).length > 0
  property real lastKeyAt: 0

  // Synced with ConfigStore for reduced motion
  readonly property bool reducedMotion: ConfigStore.reducedMotion

  // Stock Omarchy bar toggle (~/.local/state/omarchy/toggles/bar-off)
  property bool barHidden: false
  function syncHidden() { if (!hiddenProbe.running) hiddenProbe.running = true }
  Process {
    id: hiddenProbe
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: StdioCollector { onStreamFinished: root.barHidden = text.trim() === "yes" }
  }

  // Debug & inspection hooks
  property bool debugLayout: false
  property bool debugTrace: false
  property string measureResult: "{}"
  signal measureRequested()

  function normalizeWidget(name) {
    var n = String(name || "").trim()
    if (n === "home") return "settings"
    return n
  }

  function currentMode() {
    if (widgetName !== "") return "widget"
    if (hudActive) return "hud"
    if (notifActive) return "notification"
    return "idle"
  }
  readonly property string mode: currentMode()

  function modeFor(screenName) {
    var m = currentMode()
    if (m === "idle") return "idle"
    return screenName === activeScreen ? m : "idle"
  }

  readonly property bool fullscreen:
    Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.hasFullscreen : false

  readonly property bool screensaver: {
    var t = ToplevelManager.toplevels.values
    for (var i = 0; i < t.length; i++)
      if (t[i].appId === "org.omarchy.screensaver") return true
    return false
  }

  function focusedScreenName() {
    return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
  }

  function hoverIntent(over, screenName) {
    var h = Object.assign({}, hovered)
    if (over) h[screenName] = true; else delete h[screenName]
    hovered = h
  }

  // ---- widgets ----
  property bool pinned: false
  property bool keyboardExclusive: false
  property string intent: ""
  property var zoneRects: ({})

  function setZone(name, r) {
    var z = Object.assign({}, zoneRects)
    z[name] = r
    zoneRects = z
  }

  function openWidget(name, screenName, pin) {
    var normalized = normalizeWidget(name)
    pinned = !!pin
    activeScreen = (screenName && screenName !== "") ? screenName : focusedScreenName()
    widgetName = normalized
    touch()
  }

  function toggleWidget(name, screenName, pin) {
    var normalized = normalizeWidget(name)
    if (widgetName === normalized) closeWidget()
    else openWidget(normalized, screenName, pin)
  }

  function closeWidget(reason) {
    if (widgetName === "") return
    pinned = false
    keyboardExclusive = false
    console.warn("island: widget closed:", widgetName, reason || "(explicit)")
    widgetName = ""
    idleTimer.stop()
  }

  function touch(isKey) {
    if (isKey) lastKeyAt = Date.now()
    if (widgetName !== "") idleTimer.restart()
  }

  function timeoutFor(name) {
    if (name === "power") return 15000
    if (name === "settings" || name === "menu") return 25000
    return 14000
  }

  // ---- HUD ----
  function showHud(kind, value, message, ms) {
    if (widgetName !== "") return
    hudKind = kind
    hudValue = value
    hudMessage = message || ""
    hudTimer.interval = ms > 0 ? ms : 1500
    activeScreen = focusedScreenName()
    hudActive = true
    hudTimer.restart()
  }

  function hudLabel(kind) {
    var k = String(kind || "").toLowerCase()
    if (k.indexOf("volume") === 0 || k === "mute") return "Volume"
    if (k.indexOf("micro") === 0 || k.indexOf("mic") === 0) return "Mic"
    if (k === "brightness" || k === "display") return "Brightness"
    if (k === "keyboard") return "Keyboard"
    if (k === "charger") return "Power"
    return k.length ? k.charAt(0).toUpperCase() + k.slice(1) : ""
  }

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

  // ---- notification toasts ----
  readonly property int notifMs: 4500
  property var notifItem: null
  property var notifQueue: []
  property int notifSerial: 0
  property real notifLeft: 1

  Connections {
    target: Notifs
    function onArrived(n) { root.showNotif(n) }
  }

  function showNotif(n) {
    var q = notifQueue.slice()
    q.push(n)
    if (q.length > 6) q.splice(0, q.length - 6)
    notifQueue = q
    if (notifItem === null) nextNotif()
  }

  function nextNotif() {
    if (notifQueue.length === 0) {
      notifAnim.stop()
      notifItem = null
      notifActive = false
      return
    }
    var q = notifQueue.slice()
    notifItem = q.shift()
    notifQueue = q
    if (widgetName === "" && !hudActive) activeScreen = focusedScreenName()
    notifActive = true
    notifLeft = 1
    notifSerial++
    notifAnim.restart()
    notifAnim.paused = notifHeld
  }

  readonly property bool notifHeld: pointerOver || mode !== "notification"
  onNotifHeldChanged: if (notifAnim.running) notifAnim.paused = notifHeld

  function clearNotifs() {
    notifQueue = []
    notifAnim.stop()
    notifItem = null
    notifActive = false
  }

  NumberAnimation {
    id: notifAnim
    target: root
    property: "notifLeft"
    from: 1
    to: 0
    duration: root.notifMs
    onFinished: root.nextNotif()
  }

  Timer { id: hudTimer; interval: 1500; onTriggered: root.hudActive = false }
  Timer {
    id: idleTimer
    interval: root.timeoutFor(root.widgetName)
    onTriggered: {
      if (root.pinned) return
      if (root.pointerOver || Date.now() - root.lastKeyAt < 3000) restart()
      else root.checkCursor()
    }
  }

  // ---- cursor probing ----
  property var islands: ({})

  function probeCursor(screen, cb) {
    var isl = islands[screen]
    if (!isl) { cb(false, "no island"); return }
    if (cursorProbe.running) { cursorProbe.waiting.push(cb); return }
    cursorProbe.box = isl.pillBox()
    cursorProbe.waiting = [cb]
    cursorProbe.raw = ""
    cursorProbe.command = ["bash", Qt.resolvedUrl("../../assets/cursorpos.sh").toString().replace("file://", ""), screen]
    cursorProbe.running = true
  }

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
      var list = waiting
      waiting = []
      for (var i = 0; i < list.length; i++) list[i](inside, raw)
    }
    stdout: StdioCollector {
      onStreamFinished: {
        cursorProbe.raw = text.trim()
        var p = cursorProbe.raw.split(" ").map(Number)
        cursorProbe.finish(p.length === 3 && !p.some(isNaN)
          && Math.abs(p[0] - p[2] / 2) <= cursorProbe.box.width / 2 + 6
          && p[1] >= 0 && p[1] <= cursorProbe.box.height + 6)
      }
    }
    onExited: function (code) {
      if (code !== 0) {
        cursorProbe.raw = "probe failed " + code
        finish(false)
      }
    }
  }

  // ---- weather location persistence (~/.local/state/island/state.json) ----
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/island"
  property bool ready: false
  property string weatherLocation: ""

  FileView {
    id: store
    path: root.stateDir + "/state.json"
    onLoaded: {
      try {
        var j = JSON.parse(text())
        if (typeof j.weatherLocation === "string")
          root.weatherLocation = j.weatherLocation.slice(0, 80)
      } catch (e) {}
      root.ready = true
    }
    onLoadFailed: root.ready = true
  }

  Process { id: mkdir; command: ["mkdir", "-p", root.stateDir]; running: true }

  function save() {
    if (!ready) return
    store.setText(JSON.stringify({ weatherLocation: weatherLocation }, null, 2))
  }
}
