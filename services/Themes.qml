pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Themes: every theme's name, preview image and key colours, plus the current theme name.
// Restored from the cache at startup, refreshed in the background (the folder scan is ~50 ms), and the preview
// images are decoded ahead of time (same url + size as the picker's cards, so they come out of Qt's pixmap cache).
Singleton {
  id: root
  property var list: []
  property string current: ""
  readonly property bool loaded: list.length > 0

  function refresh() { if (!scan.running) scan.running = true }
  function refreshCurrent() { if (!cur.running) cur.running = true }
  function setCurrent(name) { current = name; Cache.put("themes", { list: list, current: current }) }

  Component.onCompleted: {
    var c = Cache.get("themes")
    if (c && Array.isArray(c.list)) { list = c.list; current = String(c.current || "") }
  }

  Process {
    id: scan
    command: ["bash", "-c", `
      for d in "$HOME/.config/omarchy/themes"/* "\${OMARCHY_PATH:-/usr/share/omarchy}/themes"/*; do
        [ -d "$d" ] || continue
        c="$d/colors.toml"; [ -f "$c" ] || continue
        b=$(basename "$d"); name=$(echo "$b" | sed -E 's/(^|-)([a-z])/\\1\\u\\2/g; s/-/ /g')
        g() { grep -E "^$1 *=" "$c" | head -1 | sed -E 's/.*"([^"]*)".*/\\1/'; }
        p=""; for f in preview.png preview.jpg preview.webp; do [ -f "$d/$f" ] && p="$d/$f" && break; done
        [ -z "$p" ] && p=$(ls "$d"/backgrounds/*.{png,jpg,jpeg,webp} 2>/dev/null | head -1)
        printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' "$name" "$p" "$(g background)" "$(g foreground)" "$(g accent)" "$(g red)" "$(g green)" "$(g mode)"
      done | sort -u -t$'\\t' -k1,1`]
    stdout: StdioCollector { onStreamFinished: {
      var out = []
      text.split("\n").forEach(function (l) {
        var f = l.split("\t"); if (f.length < 8 || f[0] === "") return
        out.push({ name: f[0], preview: f[1], bg: f[2], fg: f[3], accent: f[4], red: f[5], green: f[6], mode: f[7] })
      })
      if (out.length === 0) return
      // Only replace the list if something changed, so open widgets don't rebuild for nothing.
      if (JSON.stringify(out) !== JSON.stringify(root.list)) root.list = out
      Cache.put("themes", { list: root.list, current: root.current })
    } }
  }
  Process {
    id: cur
    command: ["omarchy-theme-current"]
    stdout: StdioCollector { onStreamFinished: { var n = text.trim(); if (n !== "" && n !== root.current) { root.current = n; Cache.put("themes", { list: root.list, current: n }) } } }
  }

  // Decode the preview images ahead of time (never drawn; they only warm Qt's pixmap cache).
  Item {
    Repeater {
      model: root.list
      delegate: Image { required property var modelData
        visible: false; asynchronous: true; cache: true; sourceSize: Qt.size(320, 216)
        source: /\.(png|jpe?g|webp)$/i.test(modelData.preview) ? "file://" + modelData.preview : "" }
    }
  }
}
