import QtQuick
import ".."

// Put one inside a row (or any selectable block) and bind `selected`. It tells the enclosing WidgetPanel which
// item is focused; the panel owns ONE highlight background that slides and resizes to that item, so changing the
// selection animates the highlight from the old row to the new one instead of fading two separate rectangles.
Item {
  id: root
  property bool selected: false
  property Item target: parent
  width: 0; height: 0

  function host() { var p = root.parent; while (p) { if (p.focusHost === true) return p; p = p.parent } return null }
  function sync() {
    var h = host(); if (!h) return
    if (selected) h.focusItem = target
    else Qt.callLater(function () { if (h.focusItem === target && !root.selected) h.focusItem = null })
  }
  onSelectedChanged: sync()
  Component.onCompleted: if (selected) sync()
  Component.onDestruction: { var h = host(); if (h && h.focusItem === target) h.focusItem = null }
}
