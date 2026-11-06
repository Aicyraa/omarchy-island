pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

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

  FileView { path: root.dir + "/live.json"; watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { var v = JSON.parse(text()); root.live = Array.isArray(v) ? v : [] } catch (e) { root.live = [] } } }
  FileView { path: root.dir + "/history.json"; watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { var v = JSON.parse(text()); root.history = Array.isArray(v) ? v.slice(-30).reverse() : [] } catch (e) { root.history = [] } } }

  function ago(ts) {
    var s = Math.max(0, Date.now() / 1000 - ts)
    return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + "m" : s < 86400 ? Math.floor(s / 3600) + "h" : Math.floor(s / 86400) + "d"
  }
}
