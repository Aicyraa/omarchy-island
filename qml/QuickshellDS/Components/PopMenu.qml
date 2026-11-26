pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

Surface {
    id: root

    property var rows: [] // [{ id, label, icon, destructive }]
    property int currentIndex: -1
    property real clampMargin: Tokens.space.sm

    signal chosen(string id)
    signal dismissed()

    function clampToBounds(containerWidth: real, containerHeight: real, desiredX: real, desiredY: real): point {
        const cx = Math.max(root.clampMargin, Math.min(containerWidth - root.width - root.clampMargin, desiredX))
        const cy = Math.max(root.clampMargin, Math.min(containerHeight - root.height - root.clampMargin, desiredY))
        return Qt.point(cx, cy)
    }

    role: "ground"
    radius: Tokens.radius.md
    padding: Tokens.space.xs
    implicitWidth: Tokens.size.menuWidth
    implicitHeight: column.implicitHeight + Tokens.space.xs * 2

    Accessible.role: Accessible.PopupMenu
    Accessible.name: qsTr("Context menu")

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.space.xxs

        Repeater {
            model: root.rows

            ListRow {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: Tokens.px(30)
                icon: modelData.icon ?? ""
                title: modelData.label ?? ""
                destructive: modelData.destructive ?? false
                selected: index === root.currentIndex
                onClicked: root.chosen(modelData.id)
            }
        }
    }

    Keys.onUpPressed: {
        if (root.rows.length > 0)
            root.currentIndex = (root.currentIndex - 1 + root.rows.length) % root.rows.length
    }
    Keys.onDownPressed: {
        if (root.rows.length > 0)
            root.currentIndex = (root.currentIndex + 1) % root.rows.length
    }
    Keys.onReturnPressed: {
        if (root.currentIndex >= 0 && root.currentIndex < root.rows.length)
            root.chosen(root.rows[root.currentIndex].id)
    }
    Keys.onEscapePressed: root.dismissed()
}
