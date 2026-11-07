import QtQuick
import ".."

// A small interactive icon slot for the idle pill. Children go inside; the slot
// adds the mouse behaviour the spec asks for without opening anything:
//   scroll -> scrolled(+1/-1) · middle click -> middleClicked() ·
//   left click -> clicked() · right click -> rightClicked()
Item {
  id: root
  default property alias content: box.data
  signal clicked()
  signal rightClicked()
  signal middleClicked()
  signal scrolled(int dir)

  implicitWidth: box.childrenRect.width
  implicitHeight: box.childrenRect.height
  Item { id: box; width: childrenRect.width; height: childrenRect.height }

  // Hover: a soft rounded backing behind the glyph.
  Rectangle { antialiasing: true; anchors.fill: parent; anchors.margins: -3; radius: 7; z: -1; color: Theme.text; opacity: hit.containsMouse ? 0.12 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } } }
  MouseArea {
    id: hit
    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
    anchors.fill: parent; anchors.margins: -5          // a bit bigger than the glyph: easier to hit
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: function (m) {
      if (m.button === Qt.RightButton) root.rightClicked()
      else if (m.button === Qt.MiddleButton) root.middleClicked()
      else root.clicked()
    }
    onWheel: function (w) { root.scrolled(w.angleDelta.y > 0 ? 1 : -1) }
  }
}
