pragma ComponentBehavior: Bound

import QtQuick
import "../Core"
import "../QuickshellDS/Components"

WidgetSurface {
    id: root

    preferredWidth: 420
    compact: true
    hint: qsTr("Esc close")

    EmptyState {
        width: parent.width
        icon: "sparkles"
        title: IslandState.widgetName !== "" ? IslandState.widgetName : qsTr("Widget")
        description: qsTr("This widget is not implemented yet.")
    }
}
