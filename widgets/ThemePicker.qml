import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import ".."
import "../services"

// Theme picker: ONE horizontal strip of theme cards (it scrolls sideways), about 190 px tall.
//
// Each card shows the theme's wallpaper, its name over a scrim in the theme's OWN background and
// foreground colours (so the label is always legible, whatever the island's current theme), five colour
// swatches, a sun/moon chip for light/dark, and a check on the current theme. The selected card is ringed
// and gently scaled. Cards come from the theme folders (user themes in ~/.config/omarchy/themes, built-ins
// in OMARCHY_PATH) and apply with Omarchy's own `omarchy-theme-set`.
// Keys: ←/→ move · Home/End jump · Enter apply · Esc close. The mouse wheel scrolls the strip sideways.
WidgetPanel {
  id: root
  preferredWidth: 720
  hint: "←/→ move · Home/End jump · Enter apply · Esc close"
  property var themes: []
  property string current: ""
  property string applying: ""            // name being applied (clears itself after a few seconds)
  property int sel: 0
  property bool loading: true
  readonly property var debugState: ({ sel: sel, count: themes.length, contentX: Math.round(strip.contentX) })

  readonly property int cardW: 156
  readonly property int cardH: 108

  function apply(t) {
    Cmd.run(["omarchy-theme-set", t.name]); current = t.name; applying = t.name; applyTimer.restart()
  }
  Timer { id: applyTimer; interval: 4000; onTriggered: root.applying = "" }

  onSelChanged: strip.positionViewAtIndex(sel, ListView.Contain)
  // On open, centre the current theme in the strip (arrow keys then only scroll as far as needed).
  function centerSelected() { Qt.callLater(function () { strip.positionViewAtIndex(root.sel, ListView.Center) }) }
  Keys.onPressed: function (e) {
    var n = themes.length; if (n === 0) return
    if (e.key === Qt.Key_Right) sel = Math.min(sel + 1, n - 1)
    else if (e.key === Qt.Key_Left) sel = Math.max(sel - 1, 0)
    else if (e.key === Qt.Key_Home) sel = 0
    else if (e.key === Qt.Key_End) sel = n - 1
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) apply(themes[sel])
    else return
    e.accepted = true
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
      root.centerSelected()
    } }
  }
  Process { running: true; command: ["omarchy-theme-current"]
    stdout: StdioCollector { onStreamFinished: { root.current = text.trim()
      for (var i = 0; i < root.themes.length; i++) if (root.themes[i].name === root.current) root.sel = i
      root.centerSelected() } } }


  // ---- header: title on the left, position / status on the right ----
  Item { width: parent.width; height: 24
    Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "Themes"; color: Theme.text; font.pixelSize: 15; font.bold: true }
    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
      text: root.applying !== "" ? "Applying " + root.applying + "…" : (root.themes.length > 0 ? (root.sel + 1) + " / " + root.themes.length : "")
      color: root.applying !== "" ? Theme.accentInk : Theme.textMuted; font.pixelSize: 12 }
  }
  Text { visible: root.loading; textFormat: Text.PlainText; text: "Reading themes…"; color: Theme.textMuted; font.pixelSize: 13 }

  // ---- the strip ----
  // Slightly taller than a card so the selection ring and scale are never clipped.
  Item {
    visible: !root.loading
    width: parent.width; height: root.cardH + 12
    ListView {
      id: strip
      anchors.fill: parent
      orientation: ListView.Horizontal
      spacing: Theme.s8
      clip: true
      model: root.themes
      boundsBehavior: Flickable.StopAtBounds
      highlightMoveDuration: 0
      delegate: Item {
        id: card
        required property var modelData
        required property int index
        readonly property bool selected: root.sel === index
        readonly property bool isCurrent: modelData.name === root.current
        readonly property bool hasImage: /\.(png|jpe?g|webp)$/i.test(modelData.preview)
        readonly property color themeBg: Qt.color(modelData.bg)
        readonly property color themeFg: Qt.color(modelData.fg)
        width: root.cardW; height: strip.height

        ClippingRectangle {
          id: face
          width: root.cardW; height: root.cardH; anchors.centerIn: parent
          radius: Theme.tileRadius
          color: card.themeBg
          border.width: card.selected ? 2 : 0; border.color: Theme.text
          scale: card.selected ? 1.04 : 1
          Behavior on scale { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }

          Image { visible: card.hasImage; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
            sourceSize: Qt.size(320, 216); source: card.hasImage ? "file://" + modelData.preview : "" }

          // Scrim in the theme's own background colour, so the name is legible over any wallpaper.
          Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 58
            gradient: Gradient {
              GradientStop { position: 0; color: Qt.rgba(card.themeBg.r, card.themeBg.g, card.themeBg.b, 0) }
              GradientStop { position: 0.55; color: Qt.rgba(card.themeBg.r, card.themeBg.g, card.themeBg.b, 0.88) }
              GradientStop { position: 1; color: Qt.rgba(card.themeBg.r, card.themeBg.g, card.themeBg.b, 0.96) } } }
          Text { x: Theme.s12; y: parent.height - 38; width: parent.width - 2 * Theme.s12; elide: Text.ElideRight; textFormat: Text.PlainText
            text: modelData.name; color: card.themeFg; font.pixelSize: 12; font.bold: true }
          Row { x: Theme.s12; y: parent.height - 19; spacing: 4
            Repeater { model: [modelData.bg, modelData.fg, modelData.accent, modelData.red, modelData.green]
              delegate: Rectangle { required property string modelData; width: 10; height: 10; radius: 5; color: modelData
                border.width: 1; border.color: Qt.rgba(card.themeFg.r, card.themeFg.g, card.themeFg.b, 0.35) } } }

          // light / dark chip, top-left
          Rectangle { x: Theme.s8; y: Theme.s8; width: 22; height: 22; radius: 11; color: Qt.rgba(0, 0, 0, 0.45)
            Icon { anchors.centerIn: parent; name: modelData.mode === "light" ? "sun" : "moon"; size: 13; color: Qt.rgba(1, 1, 1, 0.92) } }
          // current-theme badge, top-right
          Rectangle { visible: card.isCurrent; x: parent.width - 30; y: Theme.s8; width: 22; height: 22; radius: 11; color: Theme.accent
            Icon { anchors.centerIn: parent; name: "check"; size: 13; color: Theme.accentText; strokeWidth: 2.4 } }

          MouseArea { anchors.fill: parent; onClicked: { root.sel = card.index; root.apply(modelData) } }
        }
      }

      // Sideways fades where cards are clipped, so it reads as scrollable.
      Rectangle { visible: strip.contentX > 2; width: 22; height: parent.height; anchors.left: parent.left
        gradient: Gradient { orientation: Gradient.Horizontal
          GradientStop { position: 0; color: Theme.pill } GradientStop { position: 1; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0) } } }
      Rectangle { visible: strip.contentX < strip.contentWidth - strip.width - 2; width: 22; height: parent.height; anchors.right: parent.right
        gradient: Gradient { orientation: Gradient.Horizontal
          GradientStop { position: 0; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0) } GradientStop { position: 1; color: Theme.pill } } }
    }
    // The wheel scrolls the strip sideways (clicks pass through to the cards).
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton
      onWheel: function (w) { strip.contentX = Math.max(0, Math.min(strip.contentWidth - strip.width, strip.contentX - (w.angleDelta.y + w.angleDelta.x) * 0.8)) } }
  }
}
