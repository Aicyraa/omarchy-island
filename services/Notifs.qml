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

  // Emitted once for every notification that was not in history.json before (the island's toast listens).
  // Silenced ones (arrived under Focus) and anything arriving while Focus is on are not announced.
  // The first read only records what is already there, so starting the island announces nothing old.
  signal arrived(var n)
  property var seenKeys: null

  FileView { path: root.dir + "/live.json"; watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { var v = JSON.parse(text()); root.live = Array.isArray(v) ? v : [] } catch (e) { root.live = [] } } }
  FileView { path: root.dir + "/history.json"; watchChanges: true
    onFileChanged: reload()
    onLoaded: root.loadHistory(text()) }

  function loadHistory(raw) {
    var list = []
    try { var v = JSON.parse(raw); list = Array.isArray(v) ? v : [] } catch (e) { list = [] }
    var keys = {}
    for (var i = 0; i < list.length; i++) keys[list[i].key] = true
    if (seenKeys !== null) {
      for (var j = 0; j < list.length; j++) {          // the file is oldest first
        var n = list[j]
        if (!seenKeys[n.key] && n.closed_reason !== "silenced" && !Indicators.dnd) arrived(n)
      }
    }
    seenKeys = keys
    history = list.slice(-30).reverse()
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
