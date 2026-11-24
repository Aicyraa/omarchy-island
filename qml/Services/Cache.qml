pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Cache: a tiny persisted key -> {t, v} store (~/.local/state/island/cache.json), loaded synchronously at startup
// so the data services can restore their last known data BEFORE anything is drawn. That is what makes a widget open
// already populated, even for the first open after a login: stale-while-revalidate, never an empty "loading" state.
//   get(key) -> value | undefined      age(key) -> ms (Infinity if absent)      put(key, value)
// Writes are debounced (1.5 s). Values must be JSON-safe. Never cache anything secret here.
Singleton {
  id: root
  property var entries: ({})
  readonly property string path: Quickshell.env("HOME") + "/.local/state/island/cache.json"

  function get(key) { var e = entries[key]; return e ? e.v : undefined }
  function age(key) { var e = entries[key]; return e ? Date.now() - e.t : Infinity }
  function put(key, value) {
    var n = Object.assign({}, entries); n[key] = { t: Date.now(), v: value }; entries = n
    saveTimer.restart()
  }

  FileView { id: store; path: root.path; blockLoading: true }
  Component.onCompleted: { try { var j = JSON.parse(store.text()); if (j && typeof j === "object") entries = j } catch (e) {} }
  Timer { id: saveTimer; interval: 1500; onTriggered: store.setText(JSON.stringify(root.entries)) }
}
