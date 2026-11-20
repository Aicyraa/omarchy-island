import QtQuick
import Quickshell
import ".."

// WidgetPanel: the base every widget is built on. It is what makes panels
// CONTENT-SIZED instead of fixed-height.
//
//   * Put the widget's content inside it (it is the default property, so children
//     land in the inner Column). Each child gets the full inner width.
//   * implicitHeight = content + 2 * panelPadding, clamped to
//     [panelMinHeight, panelMaxHeight]. Island reads implicitWidth/implicitHeight
//     from the active widget and springs the pill to that size.
//   * Taller content scrolls inside a Flickable, with a fade at each clipped edge
//     and a thin scroll indicator. reveal(item) scrolls a selected item into view.
Item {
  id: panel

  default property alias content: col.data
  property string hint: ""                 // optional description of the widget's keys (no longer drawn)
  property real preferredWidth: 480
  property bool compact: false             // small toast: tighter minimum height
  property alias flick: flick
  // The shared, animated focus highlight (see FocusTarget): rows register themselves here.
  readonly property bool focusHost: true
  property Item focusItem: null
  readonly property var column: col        // exposed for the layout measurement tool

  property int pad: Theme.panelPadding     // a widget may choose a tighter edge (the menu uses 8)
  // The scrolling area is inset by `inset` at the top and bottom, so when a long list scrolls its
  // rows are clipped 8px BEFORE the pill edge instead of flush against it. The column's own
  // top/bottom padding shrinks by the same amount, so the resting padding is still exactly `pad`.
  readonly property int inset: Theme.s8
  readonly property real contentH: col.implicitHeight + 2 * pad

  // ---- no snapping while data loads ----
  // A widget whose content arrives late (a list, a fetched reading) sets `dataLoading: true`. Island hands it `reserve`, the
  // height it had last time it was fully loaded (remembered in the Cache). While loading, the panel keeps that height and
  // fills the part the real content does not cover yet with placeholder rows, so the pill opens at its final size and the
  // data just fills in. The reservation ends when loading ends, or after 2.5 s so an empty result cannot hold it forever.
  property bool dataLoading: false
  property bool useReserve: true
  property real reserve: 0
  readonly property bool reserving: useReserve && (dataLoading || Quickshell.env("ISLAND_FORCE_LOADING") === "1") && reserve > 0 && reserveTimer.running
  Timer { id: reserveTimer; interval: 2500; running: true }

  focus: true
  implicitWidth: preferredWidth
  implicitHeight: Math.max(compact ? 40 : Theme.panelMinHeight, Math.min(Theme.panelMaxHeight, reserving ? Math.max(contentH, reserve) : contentH))
  readonly property bool scrollable: contentH > height + 1

  function reveal(item) {
    if (!item) return
    var p = item.mapToItem(col, 0, 0)
    var top = p.y + (pad - inset) - Theme.s8, bottom = p.y + (pad - inset) + item.height + Theme.s8
    if (top < flick.contentY) flick.contentY = Math.max(0, top)
    else if (bottom > flick.contentY + flick.height) flick.contentY = Math.min(flick.contentHeight - flick.height, bottom - flick.height)
  }

  Flickable {
    id: flick
    y: panel.inset
    width: panel.width
    height: panel.height - 2 * panel.inset
    contentWidth: width
    contentHeight: col.implicitHeight + 2 * (panel.pad - panel.inset)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: panel.scrollable
    Behavior on contentY { enabled: !flick.moving && !flick.dragging && !bar.dragging; NumberAnimation { duration: IslandState.reducedMotion ? 0 : 120; easing.type: Easing.OutCubic } }

    // The sliding highlight behind the rows: see components/ListHighlight.qml (extracted unchanged).
    ListHighlight { host: panel; container: flick.contentItem; content: col }

    // placeholder rows for the data that has not arrived (shown only while reserving, below the real content)
    Column {
      id: skeleton
      visible: panel.reserving && rows > 0
      x: panel.pad; y: col.y + col.implicitHeight + Theme.sectionGap
      width: panel.width - 2 * panel.pad; spacing: Theme.rowGap
      readonly property real room: panel.reserve - panel.contentH - Theme.sectionGap
      readonly property int rows: Math.max(0, Math.floor((room + spacing) / (44 + spacing)))
      SequentialAnimation on opacity { running: skeleton.visible && !IslandState.reducedMotion; loops: Animation.Infinite
        NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine } }
      Repeater {
        model: skeleton.rows
        delegate: Rectangle { antialiasing: true; width: skeleton.width; height: 44; radius: Theme.tileRadius - 4; color: Theme.surface
          Rectangle { antialiasing: true; x: Theme.s12; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; radius: 13; color: Theme.mix(Theme.surface, Theme.text, 0.08) }
          Rectangle { antialiasing: true; x: Theme.s12 + 26 + Theme.s12; y: 12; width: (parent.width - 90) * (index % 2 ? 0.45 : 0.6); height: 8; radius: 4; color: Theme.mix(Theme.surface, Theme.text, 0.10) }
          Rectangle { antialiasing: true; x: Theme.s12 + 26 + Theme.s12; y: 26; width: (parent.width - 90) * (index % 2 ? 0.3 : 0.38); height: 6; radius: 3; color: Theme.mix(Theme.surface, Theme.text, 0.06) } }
      }
    }

    Column {
      id: col
      x: panel.pad; y: panel.pad - panel.inset
      width: panel.width - 2 * panel.pad
      spacing: Theme.sectionGap
    }
  }

  // ---- scroll cues: fades at the clipped edges + a thin indicator ----
  Rectangle { visible: panel.scrollable && flick.contentY > 2; width: panel.width; height: 22; y: flick.y
    gradient: Gradient { GradientStop { position: 0; color: Theme.pill } GradientStop { position: 1; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0) } } }
  Rectangle { visible: panel.scrollable && flick.contentY < flick.contentHeight - flick.height - 2
    width: panel.width; height: 22; y: flick.y + flick.height - 22
    gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0) } GradientStop { position: 1; color: Theme.pill } } }
  Scroller { id: bar; flick: flick; visible: panel.scrollable; x: panel.width - 16; width: 16; y: flick.y; height: flick.height }
}
