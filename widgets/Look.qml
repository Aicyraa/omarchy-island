import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import ".."
import "../services"

// Look: the background and the monospace font, which the menu's Appearance > Background and Appearance > Font had.
// Background: "Next" (cycles like omarchy-theme-bg-next) and the still images of the current theme (click or Enter sets one).
// Font: the monospace families fontconfig reports; the current one is marked. Tab switches between the two sections.
// Keys: Tab section · ←/→ move through backgrounds · ↑/↓ move through fonts · Enter apply · Esc close.
// The menu's Background and Font routes open this widget on the matching section (IslandState.intent).
WidgetPanel {
  id: root
  preferredWidth: 640
  hint: "Tab section · ←/→ backgrounds · ↑/↓ fonts · Enter apply · Esc close"

  property int sec: 0                       // 0 backgrounds, 1 fonts
  property int bgIdx: 0                     // 0 = Next, 1.. = the images
  property int fontIdx: 0
  property var bgs: []                      // resolved paths of the current theme's images
  property string bgCurrent: ""
  property var fonts: []
  property string fontCurrent: ""
  readonly property var bgItems: [""].concat(bgs)

  Component.onCompleted: { scanBg.running = true; scanFonts.running = true; takeIntent() }

  // The menu asks for a section: "background" or "font". It is taken when the widget is made and when a request comes
  // while it is open.
  function takeIntent() {
    var want = IslandState.intent
    if (want === "font") { sec = 1; IslandState.intent = "" }
    else if (want === "background") { sec = 0; IslandState.intent = "" }
  }
  Connections { target: IslandState; function onIntentChanged() { root.takeIntent() } }

  function applyBg(i) {
    if (i === 0) { Cmd.run(["omarchy-theme-bg-next"]); reread.restart(); return }
    var p = bgs[i - 1]
    if (!p) return
    Cmd.run(["omarchy-theme-bg-set", p]); bgCurrent = p
  }
  function applyFont(i) {
    var f = fonts[i]
    if (!f) return
    Cmd.run(["omarchy-font-set", f]); fontCurrent = f
  }
  Timer { id: reread; interval: 900; onTriggered: scanBg.running = true }

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) { sec = 1 - sec; e.accepted = true }
    else if (e.key === Qt.Key_Left && sec === 0) { bgIdx = Math.max(0, bgIdx - 1); bgList.positionViewAtIndex(bgIdx, ListView.Contain); e.accepted = true }
    else if (e.key === Qt.Key_Right && sec === 0) { bgIdx = Math.min(bgItems.length - 1, bgIdx + 1); bgList.positionViewAtIndex(bgIdx, ListView.Contain); e.accepted = true }
    else if (e.key === Qt.Key_Up && sec === 1) { fontIdx = Math.max(0, fontIdx - 1); e.accepted = true }
    else if (e.key === Qt.Key_Down && sec === 1) { fontIdx = Math.min(fonts.length - 1, fontIdx + 1); e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (sec === 0) applyBg(bgIdx); else applyFont(fontIdx); e.accepted = true }
  }

  // ---- data ----
  Process {
    id: scanBg
    command: ["bash", "-c",
      'theme=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null); '
      + 'readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null | sed "s/^/CUR\\t/"; '
      + 'find -L "$HOME/.config/omarchy/backgrounds/$theme" "$HOME/.local/state/omarchy/current/theme/backgrounds" '
      + '-maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \\) -print0 2>/dev/null '
      + '| sort -z | xargs -0 -r readlink -f | sed "s/^/BG\\t/"']
    stdout: StdioCollector { onStreamFinished: {
      var cur = "", list = []
      String(text || "").split("\n").forEach(function (l) {
        if (l.indexOf("CUR\t") === 0) cur = l.slice(4)
        else if (l.indexOf("BG\t") === 0) list.push(l.slice(3))
      })
      root.bgCurrent = cur
      root.bgs = list
    } }
  }
  Process {
    id: scanFonts
    command: ["bash", "-c", 'echo "CUR	$(omarchy-font-current 2>/dev/null)"; omarchy-font-list 2>/dev/null | sed "s/^/F\\t/"']
    stdout: StdioCollector { onStreamFinished: {
      var cur = "", list = []
      String(text || "").split("\n").forEach(function (l) {
        if (l.indexOf("CUR\t") === 0) cur = l.slice(4).trim()
        else if (l.indexOf("F\t") === 0 && l.length > 2) list.push(l.slice(2).trim())
      })
      root.fontCurrent = cur
      root.fonts = list
      var at = list.indexOf(cur)
      if (at >= 0) root.fontIdx = at
    } }
  }

  // ---- backgrounds ----
  Label { text: "Background"; color: root.sec === 0 ? Theme.text : Theme.textMuted
    font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel }
  ListView {
    id: bgList
    width: parent.width; height: 74
    orientation: ListView.Horizontal
    spacing: Theme.s8
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: root.bgItems
    delegate: Item {
      required property string modelData
      required property int index
      readonly property bool isNext: index === 0
      readonly property bool isCurrent: !isNext && modelData === root.bgCurrent
      readonly property bool selected: root.sec === 0 && root.bgIdx === index
      width: 112; height: bgList.height
      ClippingRectangle {
        anchors.fill: parent; radius: Theme.tileRadius; color: Theme.surface
        Image { visible: !isNext; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
          sourceSize: Qt.size(224, 148); source: isNext ? "" : "file://" + modelData }
        Rectangle { visible: isNext; anchors.fill: parent; color: Theme.surfaceRaised
          Icon { anchors.centerIn: parent; name: "next"; size: Theme.iconMd; color: Theme.text } }
        SmoothRect { visible: isCurrent; x: Theme.s8; y: Theme.s8; width: 22; height: 22; radius: 11; color: Theme.accentFill
          Icon { anchors.centerIn: parent; name: "check"; size: 13; color: Theme.accentText; strokeWidth: 2.4 } }
        Label { visible: isNext; anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 20
          text: "Next"; color: Theme.text; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel }
        FocusRing { on: selected; radius: Theme.tileRadius }
        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: { root.sec = 0; root.bgIdx = index; root.applyBg(index) } }
      }
    }
  }
  Label { visible: root.bgs.length === 0; text: "No backgrounds for this theme"
    color: Theme.textMuted; font.pixelSize: Theme.typeBody }

  // ---- fonts ----
  Label { topPadding: Theme.s12; text: "Font"; color: root.sec === 1 ? Theme.text : Theme.textMuted
    font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel }
  Column {
    width: parent.width
    Repeater {
      model: root.fonts
      delegate: ListRow {
        required property string modelData
        required property int index
        width: parent.width
        title: modelData
        subtitle: "Monospace"
        active: modelData === root.fontCurrent
        selected: root.sec === 1 && root.fontIdx === index
        onSelectedChanged: if (selected) root.reveal(this)
        onClicked: { root.sec = 1; root.fontIdx = index; root.applyFont(index) }
      }
    }
  }
}
