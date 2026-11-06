import QtQuick
import ".."

WidgetPanel {
  compact: true
  preferredWidth: 260
  hint: ""
  Text { textFormat: Text.PlainText; text: IslandState.widgetName + " (not built yet)"; color: Theme.textMuted; font.pixelSize: 13 }
}
