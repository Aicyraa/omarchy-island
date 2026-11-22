import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import ".."
import "../services"

// Theme picker: horizontal strip of theme cards with immediate keyboard search
// (`wantsKeyboard: true` + `initialFocus: searchInput`), clear Current theme badge + accent ring,
// and silky-smooth GPU-scaled selection animation that never jitters or clips on the last theme.
// Keys: type to search · ←/→ move · Home/End jump · Enter apply · Esc clear search / close.
WidgetPanel {
  id: root
  preferredWidth: 720
  readonly property bool wantsKeyboard: true
  readonly property Item initialFocus: searchInput
  readonly property bool capturesEscape: query !== ""
  hint: "type to search · ←/→ move · Enter apply · Esc close"

  readonly property var all: Themes.list
  property string query: ""
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
  property bool moved: false
  property string applying: ""
  property int sel: 0
  readonly property bool loading: !Themes.loaded
  dataLoading: !Themes.loaded
  readonly property var debugState: ({ sel: sel, count: themes.length, total: all.length, query: query, contentX: Math.round(strip.contentX) })

  // Constant slot width keeps strip.contentWidth 100% stable so SpringAnimation on contentX
  // never fights delegate resizing (especially at the last visible / final theme card).
  readonly property int cardW: 156
  readonly property int cardH: 108
  readonly property int slotW: 174
  readonly property int stripPad: 10
  readonly property real growScale: 1.09
  property bool snapping: false

  function follow() {
    if (sel < 0 || themes.length === 0) return
    var step = slotW + strip.spacing
    var center = stripPad + sel * step + slotW / 2
    var target = center - strip.width / 2
    var maxX = Math.max(0, strip.contentWidth - strip.width)
    strip.contentX = Math.max(0, Math.min(maxX, target))
  }
  function snapTo() { snapping = true; follow(); snapping = false }
  onSelChanged: follow()
  onQueryChanged: {
    moved = true
    sel = 0
    Qt.callLater(function () { snapTo() })
  }

  function clearSearch() {
    searchInput.text = ""
    query = ""
  }
  function apply(t) {
    Cmd.run(["omarchy-theme-set", t.name]); Themes.setCurrent(t.name); applying = t.name; applyTimer.restart()
  }
  Timer { id: applyTimer; interval: 4000; onTriggered: root.applying = "" }

  function centerSelected() { Qt.callLater(function () { snapTo() }) }
  function syncToCurrent() {
    if (moved) return
    for (var i = 0; i < themes.length; i++) if (themes[i].name === current) { sel = i; break }
    centerSelected()
  }
  Component.onCompleted: {
    syncToCurrent()
    Themes.refreshCurrent()
    Themes.refresh()
    Qt.callLater(function () { searchInput.forceActiveFocus() })
  }
  onCurrentChanged: syncToCurrent()
  onThemesChanged: syncToCurrent()

  Keys.onPressed: function (e) {
    var n = themes.length
    if (e.key === Qt.Key_Escape && query !== "") { clearSearch(); e.accepted = true; return }
    if (n === 0) return
    if (e.key === Qt.Key_Right) { moved = true; sel = Math.min(sel + 1, n - 1); e.accepted = true }
    else if (e.key === Qt.Key_Left) { moved = true; sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_Home) { moved = true; sel = 0; e.accepted = true }
    else if (e.key === Qt.Key_End) { moved = true; sel = n - 1; e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (themes[sel]) apply(themes[sel]); e.accepted = true }
  }

  // ---- header: real focusable search pill on left, status + counter on right ----
  Item {
    width: parent.width; height: 32
    SmoothRect {
      id: searchBox
      anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
      height: 32; width: 260; radius: 16
      color: searchInput.activeFocus || root.query !== "" ? Theme.mix(Theme.surface, Theme.text, 0.08) : Theme.surface
      borderWidth: searchInput.activeFocus ? 1 : 0
      borderColor: Qt.rgba(Theme.accentInk.r, Theme.accentInk.g, Theme.accentInk.b, 0.7)
      Behavior on color { ColorAnimation { duration: 120 } }

      Icon { id: searchIcon; x: Theme.s12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: Theme.iconSm; color: searchInput.activeFocus ? Theme.accentInk : Theme.textMuted }

      TextInput {
        id: searchInput
        anchors.left: searchIcon.right; anchors.leftMargin: Theme.s8
        anchors.right: clearBtn.visible ? clearBtn.left : parent.right; anchors.rightMargin: Theme.s8
        anchors.verticalCenter: parent.verticalCenter
        selectByMouse: true
        clip: true
        renderType: Theme.textRenderType
        font.family: Theme.fontFamily
        font.hintingPreference: Theme.fontHinting
        color: Theme.text; selectionColor: Theme.accentFill; selectedTextColor: Theme.accentText
        font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel
        onTextChanged: if (root.query !== text) root.query = text
        onAccepted: if (root.themes[root.sel]) root.apply(root.themes[root.sel])
        Keys.onPressed: function (e) {
          var n = root.themes.length
          if (e.key === Qt.Key_Escape && root.query !== "") { root.clearSearch(); e.accepted = true }
          else if (e.key === Qt.Key_Right && (text.length === 0 || cursorPosition === text.length)) {
            if (n > 0) { root.moved = true; root.sel = Math.min(root.sel + 1, n - 1) }
            e.accepted = true
          } else if (e.key === Qt.Key_Left && (text.length === 0 || cursorPosition === 0)) {
            if (n > 0) { root.moved = true; root.sel = Math.max(root.sel - 1, 0) }
            e.accepted = true
          } else if (e.key === Qt.Key_Down && n > 0) {
            root.moved = true; root.sel = Math.min(root.sel + 1, n - 1); e.accepted = true
          } else if (e.key === Qt.Key_Up && n > 0) {
            root.moved = true; root.sel = Math.max(root.sel - 1, 0); e.accepted = true
          } else if (e.key === Qt.Key_Home && text.length === 0 && n > 0) {
            root.moved = true; root.sel = 0; e.accepted = true
          } else if (e.key === Qt.Key_End && text.length === 0 && n > 0) {
            root.moved = true; root.sel = n - 1; e.accepted = true
          }
        }
      }

      Label {
        visible: searchInput.text === ""
        anchors.left: searchInput.left; anchors.right: parent.right; anchors.rightMargin: Theme.s12
        anchors.verticalCenter: parent.verticalCenter
        text: "Search themes…"; color: Theme.textMuted; font.pixelSize: Theme.typeBody
      }

      SmoothRect {
        id: clearBtn
        visible: root.query !== ""
        anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
        width: 20; height: 20; radius: 10
        color: clrSearchArea.containsMouse ? Theme.surfaceRaised : "transparent"
        Icon { anchors.centerIn: parent; name: "x"; size: 11; color: Theme.textMuted }
        MouseArea { id: clrSearchArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clearSearch() }
      }

      MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.IBeamCursor; onClicked: searchInput.forceActiveFocus() }
    }

    Row {
      anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
      SmoothRect {
        visible: root.current !== "" && root.applying === ""
        height: 24; width: curChipRow.implicitWidth + 16; radius: 12; color: Theme.surface
        Row {
          id: curChipRow; anchors.centerIn: parent; spacing: 5
          SmoothRect { width: 6; height: 6; radius: 3; color: Theme.accentInk; anchors.verticalCenter: parent.verticalCenter }
          Label { text: root.current; color: Theme.text; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel; anchors.verticalCenter: parent.verticalCenter }
        }
      }
      Label {
        anchors.verticalCenter: parent.verticalCenter; mono: root.applying === ""
        text: root.applying !== "" ? ("Applying " + root.applying + "…")
            : (root.themes.length > 0 ? ((root.sel + 1) + " / " + root.themes.length)
               : (root.query !== "" ? ("0 / " + root.all.length) : ""))
        color: root.applying !== "" ? Theme.accentInk : Theme.textMuted; font.pixelSize: Theme.typeBody
      }
    }
  }

  Label {
    visible: !root.loading && root.all.length > 0 && root.themes.length === 0
    text: "No theme matches \"" + root.query + "\""; color: Theme.textMuted; font.pixelSize: Theme.typeTitle
  }
  Label { visible: root.loading; text: "Reading themes…"; color: Theme.textMuted; font.pixelSize: Theme.typeTitle }

  // ---- horizontal theme strip (GPU scale, fixed slot widths, zero last-card jitter) ----
  Item {
    visible: !root.loading && root.themes.length > 0
    width: parent.width; height: Math.round(root.cardH * root.growScale) + 18
    ListView {
      id: strip
      anchors.fill: parent
      orientation: ListView.Horizontal
      spacing: Theme.s4
      leftMargin: root.stripPad
      rightMargin: root.stripPad
      clip: true
      model: root.themes
      boundsBehavior: Flickable.StopAtBounds
      highlightMoveDuration: 0
      Behavior on contentX {
        enabled: !IslandState.reducedMotion && !root.snapping && !strip.dragging && !strip.flicking
        SpringAnimation { spring: 4.8; damping: 0.52; epsilon: 0.5 }
      }

      delegate: Item {
        id: card
        required property var modelData
        required property int index
        readonly property bool selected: root.sel === index
        readonly property bool isCurrent: modelData.name === root.current
        readonly property bool hasImage: /\.(png|jpe?g|webp)$/i.test(modelData.preview)
        readonly property color themeBg: Qt.color(modelData.bg)
        readonly property color themeFg: Qt.color(modelData.fg)
        width: root.slotW; height: strip.height
        z: selected ? 2 : (cardHover.hovered ? 1 : 0)

        HoverHandler { id: cardHover }

        ClippingRectangle {
          id: face
          width: root.cardW; height: root.cardH; anchors.centerIn: parent
          radius: Theme.tileRadius
          color: card.themeBg
          scale: card.selected ? root.growScale : (cardHover.hovered ? 1.03 : 1.0)
          Behavior on scale {
            enabled: !IslandState.reducedMotion
            SpringAnimation { spring: 4.2; damping: 0.46; epsilon: 0.002 }
          }

          Image {
            visible: card.hasImage; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
            sourceSize: Qt.size(320, 216); source: card.hasImage ? "file://" + modelData.preview : ""
          }

          // Scrim in the theme's own background colour.
          Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 58
            gradient: Gradient {
              GradientStop { position: 0; color: Qt.rgba(card.themeBg.r, card.themeBg.g, card.themeBg.b, 0) }
              GradientStop { position: 0.55; color: Qt.rgba(card.themeBg.r, card.themeBg.g, card.themeBg.b, 0.88) }
              GradientStop { position: 1; color: Qt.rgba(card.themeBg.r, card.themeBg.g, card.themeBg.b, 0.96) }
            }
          }
          Label {
            x: Theme.s12; y: parent.height - 38; width: parent.width - 2 * Theme.s12; elide: Text.ElideRight
            renderType: Text.QtRendering
            text: modelData.name; color: card.themeFg; font.pixelSize: Theme.typeBody; font.weight: Theme.weightStrong
          }
          Row {
            x: Theme.s12; y: parent.height - 19; spacing: 4
            Repeater {
              model: [modelData.bg, modelData.fg, modelData.accent, modelData.red, modelData.green]
              delegate: SmoothRect {
                required property string modelData; width: 10; height: 10; radius: 5; color: modelData
                borderWidth: 1; borderColor: Qt.rgba(card.themeFg.r, card.themeFg.g, card.themeFg.b, 0.35)
              }
            }
          }

          // Light / dark chip, top-left
          SmoothRect {
            x: Theme.s8; y: Theme.s8; width: 22; height: 22; radius: 11; color: Qt.rgba(0, 0, 0, 0.50)
            Icon { anchors.centerIn: parent; name: modelData.mode === "light" ? "sun" : "moon"; size: 12; color: Qt.rgba(1, 1, 1, 0.92) }
          }

          // Improved auto-sized Current badge, top-right
          SmoothRect {
            visible: card.isCurrent
            anchors.right: parent.right; anchors.rightMargin: Theme.s8
            anchors.top: parent.top; anchors.topMargin: Theme.s8
            height: 22; width: currentRow.implicitWidth + 14; radius: 11; color: Theme.accentFill
            Row {
              id: currentRow; anchors.centerIn: parent; spacing: 4
              Icon { name: "check"; size: 11; color: Theme.accentText; strokeWidth: 2.5; anchors.verticalCenter: parent.verticalCenter }
              Label { renderType: Text.QtRendering; text: "Current"; color: Theme.accentText; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightStrong; anchors.verticalCenter: parent.verticalCenter }
            }
          }

          // Crisp highlight ring for the current / selected card
          SmoothRect {
            anchors.fill: parent; radius: Theme.tileRadius; color: "transparent"
            borderWidth: card.isCurrent ? 2 : (card.selected ? 1 : 0)
            borderColor: card.isCurrent ? Theme.accentInk : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.65)
          }

          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: { root.moved = true; root.sel = card.index; root.apply(modelData) }
          }
        }
      }

      // Edge fades indicating horizontal scrollability
      Rectangle {
        visible: strip.contentX > 2; width: 22; height: parent.height; anchors.left: parent.left
        gradient: Gradient { orientation: Gradient.Horizontal
          GradientStop { position: 0; color: Theme.pill } GradientStop { position: 1; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0) } }
      }
      Rectangle {
        visible: strip.contentX < strip.contentWidth - strip.width - 2; width: 22; height: parent.height; anchors.right: parent.right
        gradient: Gradient { orientation: Gradient.Horizontal
          GradientStop { position: 0; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0) } GradientStop { position: 1; color: Theme.pill } }
      }
    }
    MouseArea {
      anchors.fill: parent; acceptedButtons: Qt.NoButton
      onWheel: function (w) {
        var maxX = Math.max(0, strip.contentWidth - strip.width)
        strip.contentX = Math.max(0, Math.min(maxX, strip.contentX - (w.angleDelta.y + w.angleDelta.x) * 0.8))
      }
    }
  }
}
