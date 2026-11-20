pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

// Notifs: read-only view of the notification files the Omarchy shell writes.
// The shell OWNS the notification server (org.freedesktop.Notifications); the
// island must never start a second one. We only watch its state files with
// inotify (`watchChanges`), so there is no polling.
Singleton {
  id: root
  readonly property string dir: Quickshell.env("HOME") + "/.local/state/omarchy/notifications"
  property var live: []
  property var history: []
  readonly property int liveCount: live.length
  // "All caught up" when nothing is on screen.
  readonly property string summary: liveCount === 0 ? "All caught up" : (liveCount === 1 ? "1 new" : liveCount + " new")

  // Emitted once for every notification that reaches the screen (the island's toast listens).
  // The shell writes a notification into live.json the moment it arrives, so that file is the arrival signal.
  // history.json is NOT: a notification only lands there when it closes, and silenced ones (Focus) go only there,
  // so Focus is respected by the shell's own rule (urgent and code notifications still come through live).
  // The first read only records what is already there, so starting the island announces nothing old.
  signal arrived(var n)
  property var seenKeys: ({})
  property bool primed: false

  FileView { path: root.dir + "/live.json"; watchChanges: true
    onFileChanged: reload()
    onLoaded: root.loadLive(text()) }
  FileView { path: root.dir + "/history.json"; watchChanges: true
    onFileChanged: reload()
    onLoaded: root.loadHistory(text()) }

  function parseList(raw) {
    try { var v = JSON.parse(raw); return Array.isArray(v) ? v : [] } catch (e) { return [] }
  }

  function loadLive(raw) {
    var list = parseList(raw)
    live = list
    var fresh = []
    for (var i = 0; i < list.length; i++) {            // the file is oldest first on screen
      var k = list[i].key
      if (k !== undefined && !seenKeys[k]) { fresh.push(list[i]); seenKeys[k] = true }
    }
    if (primed) for (var j = 0; j < fresh.length; j++) arrived(fresh[j])
    primed = true
  }

  function loadHistory(raw) {
    var list = parseList(raw).slice()
    list.sort(function (a, b) { return (Number(b.closed_ts || b.ts || 0)) - (Number(a.closed_ts || a.ts || 0)) })
    history = list.slice(0, 30)
  }

  function removeItem(key) {
    if (!key) return
    history = history.filter(function (x) { return x.key !== key })
    Cmd.run(["omarchy-shell", "-q", "notifications", "removeHistory", String(key)])
  }

  function clearAll() {
    history = []
    Cmd.run(["omarchy-shell", "-q", "notifications", "clearHistory"])
    Cmd.run(["omarchy-shell", "-q", "notifications", "dismissAll"])
  }

  function ago(ts) {
    var s = Math.max(0, Date.now() / 1000 - ts)
    return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + "m" : s < 86400 ? Math.floor(s / 3600) + "h" : Math.floor(s / 86400) + "d"
  }

  // First absolute image path found anywhere in a notification's open/edit action (JSON text), "" if none.
  function imageIn(v) {
    if (typeof v === "string") return /^\/.*\.(png|jpe?g|webp|gif|bmp)$/i.test(v) ? v : ""
    if (Array.isArray(v)) { for (var i = 0; i < v.length; i++) { var r = imageIn(v[i]); if (r !== "") return r } return "" }
    if (v && typeof v === "object") { for (var k in v) { var q = imageIn(v[k]); if (q !== "") return q } }
    return ""
  }
  function previewOf(n) {
    try { var a = imageIn(JSON.parse(n.execArgv || "[]")); if (a !== "") return a } catch (e) {}
    try { return imageIn(JSON.parse(n.execActions || "[]")) } catch (e) { return "" }
  }
  // The app icon: the notification's own icon name, else its desktop entry's icon, else an icon named like the app.
  // Quickshell.iconPath(name, true) is "" when the theme has no such icon.
  function iconNameOf(n) {
    var app = String(n.app || "")
    var e = app !== "" ? (DesktopEntries.heuristicLookup(app) || DesktopEntries.heuristicLookup(app.toLowerCase())) : null
    var cands = [String(n.appIcon || ""), e ? String(e.icon || "") : "", app.toLowerCase(), app.toLowerCase().replace(/\s+/g, "-")]
    for (var i = 0; i < cands.length; i++) if (cands[i] !== "" && Quickshell.iconPath(cands[i], true) !== "") return cands[i]
    return ""
  }
}
