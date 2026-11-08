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
// Keys: ←/→ move · Home/End jump · Enter apply · Esc clears the search, then closes. Type to search by name.
// The mouse wheel scrolls the strip sideways. The selected card springs up in scale as it is picked.
WidgetPanel {
  id: root
  preferredWidth: 720
  hint: "type to search · ←/→ move · Enter apply · Esc close"
  // Data comes from the Themes service (cached, preloaded): the strip is populated on the first frame.
  readonly property var all: Themes.list
  property string query: ""
  // Esc clears a non-empty search before it closes the widget (Island checks this flag).
  readonly property bool capturesEscape: query !== ""
  // The themes whose name matches the search: every character in order (case-insensitive), so "gru" finds Gruvbox.
  readonly property var themes: {
    var q = query.toLowerCase().replace(/\s+/g, "")
    if (q === "") return all
    return all.filter(function (t) {
      var n = String(t.name).toLowerCase(), i = 0
      for (var k = 0; k < n.length && i < q.length; k++) if (n[k] === q[i]) i++
      return i === q.length
    })
  }
  readonly property string current: Themes.current
  property bool moved: false              // the user has moved the selection: stop re-syncing it to the current theme
  property string applying: ""            // name being applied (clears itself after a few seconds)
  property int sel: 0
  readonly property bool loading: !Themes.loaded
  dataLoading: !Themes.loaded
  readonly property var debugState: ({ sel: sel, count: themes.length, total: all.length, query: query, contentX: Math.round(strip.contentX) })
  onQueryChanged: { moved = true; sel = 0; if (themes.length > 0) Qt.callLater(function () { strip.positionViewAtBeginning() }) }

  readonly property int cardW: 156
  readonly property int cardH: 108

  function apply(t) {
    Cmd.run(["omarchy-theme-set", t.name]); Themes.setCurrent(t.name); applying = t.name; applyTimer.restart()
  }
  Timer { id: applyTimer; interval: 4000; onTriggered: root.applying = "" }

  onSelChanged: strip.positionViewAtIndex(sel, ListView.Contain)
  // On open, centre the current theme in the strip (arrow keys then only scroll as far as needed).
  function centerSelected() { Qt.callLater(function () { strip.positionViewAtIndex(root.sel, ListView.Center) }) }
  Keys.onPressed: function (e) {
    var n = themes.length
    moved = true
    if (e.key === Qt.Key_Escape && query !== "") query = ""
    else if (e.key === Qt.Key_Backspace && query !== "") query = query.slice(0, -1)
    else if (n === 0 && e.text.length === 1 && e.text >= " " && e.text !== " ") query += e.text
    else if (n === 0) return
    else if (e.text.length === 1 && e.text >= " " && e.text !== " " && !(e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) query += e.text
    else if (e.key === Qt.Key_Right) sel = Math.min(sel + 1, n - 1)
    else if (e.key === Qt.Key_Left) sel = Math.max(sel - 1, 0)
    else if (e.key === Qt.Key_Home) sel = 0
    else if (e.key === Qt.Key_End) sel = n - 1
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (themes[sel]) apply(themes[sel]) }
    else return
    e.accepted = true
  }

  // Start on the current theme, centred. A background refresh that finds a different current theme (changed outside
  // the picker) re-syncs, unless the user has already started moving.
  function syncToCurrent() {
    if (moved) return
    for (var i = 0; i < themes.length; i++) if (themes[i].name === current) { sel = i; break }
    centerSelected()
  }
  Component.onCompleted: { syncToCurrent(); Themes.refreshCurrent(); Themes.refresh() }
  onCurrentChanged: syncToCurrent()
  onThemesChanged: syncToCurrent()

  // ---- header: the search box on the left; the position (or "Applying …") on the right ----
  Item { width: parent.width; height: 26
    Rectangle {
      id: searchBox
      antialiasing: true
      anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
      height: 26; width: 230; radius: 13
      color: root.query !== "" ? Theme.mix(Theme.surface, Theme.text, 0.08) : Theme.surface
      Behavior on color { ColorAnimation { duration: 120 } }
      Icon { id: searchIcon; x: Theme.s12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: Theme.iconSm; color: Theme.textMuted }
      Text { x: Theme.s12 + Theme.iconSm + Theme.s8; width: parent.width - x - Theme.s12; anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight; textFormat: Text.PlainText
        text: root.query === "" ? "Search themes…" : root.query
        color: root.query === "" ? Theme.textMuted : Theme.text; font.pixelSize: 12; font.weight: root.query === "" ? Font.Normal : Theme.weightLabel }
      Rectangle {                                    // a caret after the typed text
        visible: root.query !== "" && root.activeFocus; antialiasing: true
        x: Math.min(parent.width - 10, Theme.s12 + Theme.iconSm + Theme.s8 + queryM.advanceWidth + 2); anchors.verticalCenter: parent.verticalCenter
        width: 1.5; height: 13; color: Theme.text
        SequentialAnimation on opacity { running: parent.visible; loops: Animation.Infinite
          NumberAnimation { to: 0; duration: 500 } NumberAnimation { to: 1; duration: 500 } } }
      TextMetrics { id: queryM; font.pixelSize: 12; font.weight: Theme.weightLabel; text: root.query }
    }
    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
      text: root.applying !== "" ? "Applying " + root.applying + "…"
            : (root.themes.length > 0 ? (root.sel + 1) + " / " + root.themes.length
               : (root.query !== "" ? "0 / " + root.all.length : ""))
      color: root.applying !== "" ? Theme.accentInk : Theme.textMuted; font.pixelSize: 12 }
  }
  Text { visible: !root.loading && root.all.length > 0 && root.themes.length === 0; textFormat: Text.PlainText
    text: "No theme matches \"" + root.query + "\""; color: Theme.textMuted; font.pixelSize: 13 }
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
          // The selected card springs up in scale (and back down when the selection leaves it); hover is a smaller spring.
          scale: card.selected ? 1.06 : (cardArea.containsMouse ? 1.025 : 1)
          Behavior on scale { enabled: !IslandState.reducedMotion; SpringAnimation { spring: 4.2; damping: 0.36; epsilon: 0.002 } }

          Image { visible: card.hasImage; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
            sourceSize: Qt.size(320, 216); source: card.hasImage ? "file://" + modelData.preview : "" }

          // Scrim in the theme's own background colour, so the name is legible over any wallpaper.
          Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 58
            gradient: Gradient {
              GradientStop { position: 0; color: Qt.rgba(card.themeBg.r, card.themeBg.g, card.themeBg.b, 0) }
              GradientStop { position: 0.55; color: Qt.rgba(card.themeBg.r, card.themeBg.g, card.themeBg.b, 0.88) }
              GradientStop { position: 1; color: Qt.rgba(card.themeBg.r, card.themeBg.g, card.themeBg.b, 0.96) } } }
          Text { x: Theme.s12; y: parent.height - 38; width: parent.width - 2 * Theme.s12; elide: Text.ElideRight; textFormat: Text.PlainText
            text: modelData.name; color: card.themeFg; font.pixelSize: 12; font.weight: Theme.weightLabel }
          Row { x: Theme.s12; y: parent.height - 19; spacing: 4
            Repeater { model: [modelData.bg, modelData.fg, modelData.accent, modelData.red, modelData.green]
              delegate: Rectangle { antialiasing: true; required property string modelData; width: 10; height: 10; radius: 5; color: modelData
                border.width: 1; border.color: Qt.rgba(card.themeFg.r, card.themeFg.g, card.themeFg.b, 0.35) } } }

          // light / dark chip, top-left
          Rectangle { antialiasing: true; x: Theme.s8; y: Theme.s8; width: 22; height: 22; radius: 11; color: Qt.rgba(0, 0, 0, 0.45)
            Icon { anchors.centerIn: parent; name: modelData.mode === "light" ? "sun" : "moon"; size: 13; color: Qt.rgba(1, 1, 1, 0.92) } }
          // current-theme badge, top-right
          Rectangle { antialiasing: true; visible: card.isCurrent; x: parent.width - 30; y: Theme.s8; width: 22; height: 22; radius: 11; color: Theme.accentFill
            Icon { anchors.centerIn: parent; name: "check"; size: 13; color: Theme.accentText; strokeWidth: 2.4 } }

          MouseArea { id: cardArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.sel = card.index; root.apply(modelData) } }
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
