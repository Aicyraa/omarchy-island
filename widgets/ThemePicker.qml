import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Theme picker: cards with colour swatches and a wallpaper preview, built from the
// theme folders (user themes in ~/.config/omarchy/themes, built-ins in OMARCHY_PATH).
// The current theme is marked. Applying uses Omarchy's own `omarchy-theme-set`.
// Keys: arrows move · Enter apply · Esc close.
Item {
  id: root
  focus: true
  property string hint: "arrows move · Enter apply · Esc close"
  property var themes: []
  property string current: ""
  property int sel: 0
  property bool loading: true
  readonly property int cols: 4

  function apply(t) { Cmd.run(["omarchy-theme-set", t.name]); current = t.name }

  Keys.onPressed: function (e) {
    var n = themes.length; if (n === 0) return
    if (e.key === Qt.Key_Right) sel = Math.min(sel + 1, n - 1)
    else if (e.key === Qt.Key_Left) sel = Math.max(sel - 1, 0)
    else if (e.key === Qt.Key_Down) sel = Math.min(sel + cols, n - 1)
    else if (e.key === Qt.Key_Up) sel = Math.max(sel - cols, 0)
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) apply(themes[sel])
    else return
    grid.positionViewAtIndex(sel, GridView.Contain); e.accepted = true
  }

  // One batched read of every theme's name, preview image and key colours.
  Process {
    running: true
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
      root.themes = out; root.loading = false
      for (var i = 0; i < out.length; i++) if (out[i].name === root.current) root.sel = i
    } }
  }
  Process { running: true; command: ["omarchy-theme-current"]
    stdout: StdioCollector { onStreamFinished: { root.current = text.trim()
      for (var i = 0; i < root.themes.length; i++) if (root.themes[i].name === root.current) root.sel = i } } }

  Text { x: 22; y: 14; textFormat: Text.PlainText; text: "Themes"; color: Theme.text; font.pixelSize: 15; font.bold: true }
  Text { visible: root.loading; anchors.centerIn: parent; textFormat: Text.PlainText
    text: "Reading themes…"; color: Theme.textMuted; font.pixelSize: 13 }

  GridView {
    id: grid
    x: 14; y: 44; width: root.width - 28; height: root.height - 54
    clip: true; model: root.themes
    cellWidth: width / root.cols; cellHeight: 132
    delegate: Item {
      required property var modelData
      required property int index
      width: grid.cellWidth; height: grid.cellHeight
      Rectangle { anchors.fill: parent; anchors.margins: 5; radius: 16; color: Theme.surface; clip: true
        border.width: root.sel === index ? 2 : 0; border.color: Theme.text
        // wallpaper preview (images only; loaded lazily for visible cards)
        Image { x: 0; y: 0; width: parent.width; height: 78; fillMode: Image.PreserveAspectCrop; asynchronous: true
          sourceSize: Qt.size(240, 160)
          source: /\.(png|jpe?g|webp)$/i.test(modelData.preview) ? "file://" + modelData.preview : "" }
        Rectangle { visible: !(/\.(png|jpe?g|webp)$/i.test(modelData.preview)); width: parent.width; height: 78; color: modelData.bg }
        Text { x: 10; y: 84; width: parent.width - 60; elide: Text.ElideRight; textFormat: Text.PlainText
          text: modelData.name; color: Theme.text; font.pixelSize: 12; font.bold: true }
        Row { x: 10; y: 106; spacing: 4
          Repeater { model: [modelData.bg, modelData.fg, modelData.accent, modelData.red, modelData.green]
            delegate: Rectangle { required property string modelData; width: 12; height: 12; radius: 6; color: modelData
              border.width: 1; border.color: Theme.outline } } }
        Icon { visible: modelData.name === root.current; anchors.right: parent.right; anchors.rightMargin: 8; y: 84
          name: "check"; size: 16; color: Theme.success }
        MouseArea { anchors.fill: parent; onClicked: { root.sel = index; root.apply(modelData) } }
      }
    }
  }
}
