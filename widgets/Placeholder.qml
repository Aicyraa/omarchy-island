import QtQuick
import ".."

Item {
  property string hint: "Esc close"
  focus: true
  Text {
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: IslandState.widgetName + " (not built yet)"
    color: Theme.textMuted; font.pixelSize: 14
  }
}
