pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// ActiveApps: event-driven list of mapped windows on the focused Hyprland workspace.
// Zero polling: updates only on Hyprland raw events (50ms debounce) and initial load.
Singleton {
  id: root

  property var apps: []

  readonly property var watchedEvents: ({
    "workspace": true,
    "workspacev2": true,
    "focusedmon": true,
    "openwindow": true,
    "closewindow": true,
    "movewindow": true,
    "movewindowv2": true,
    "activewindow": true,
    "windowtitle": true
  })

  function focusApp(address: string): void {
    if (!address) return
    if (Hyprland.usingLua)
      Hyprland.dispatch('hl.dsp.focus_window({address="' + address + '"})')
    else
      Hyprland.dispatch("focuswindow address:" + address)
  }

  Connections {
    target: Hyprland
    function onRawEvent(ev) {
      if (ev && root.watchedEvents[ev.name])
        refreshDebounce.restart()
    }
  }

  Timer {
    id: refreshDebounce
    interval: 50
    repeat: false
    onTriggered: if (!clientsProc.running) clientsProc.running = true
  }

  Process {
    id: clientsProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var clients = JSON.parse(text)
          if (!Array.isArray(clients)) return
          var wsId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
          var filtered = clients.filter(function(c) {
            return c && c.workspace && c.workspace.id === wsId && c.mapped !== false
          })
          filtered.sort(function(a, b) {
            var fa = typeof a.focusHistoryID === "number" ? a.focusHistoryID : 999999
            var fb = typeof b.focusHistoryID === "number" ? b.focusHistoryID : 999999
            if (fa !== fb) return fa - fb
            var ax = Array.isArray(a.at) && a.at.length > 0 ? a.at[0] : 0
            var bx = Array.isArray(b.at) && b.at.length > 0 ? b.at[0] : 0
            return ax - bx
          })
          var out = []
          for (var i = 0; i < filtered.length; i++) {
            var c = filtered[i]
            var cls = String(c["class"] || c.initialClass || "")
            var entry = cls !== "" ? (DesktopEntries.heuristicLookup(cls) || DesktopEntries.heuristicLookup(cls.toLowerCase())) : null
            var iconSource = entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
            out.push({
              address: String(c.address || ""),
              className: cls,
              title: String(c.title || cls || ""),
              iconSource: iconSource,
              focused: c.focusHistoryID === 0
            })
          }
          root.apps = out
        } catch (e) {}
      }
    }
  }

  Component.onCompleted: clientsProc.running = true
}
