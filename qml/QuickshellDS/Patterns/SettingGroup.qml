import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

ColumnLayout {
    id: root

    property string title: ""
    default property alias rows: rowsColumn.data

    Layout.fillWidth: true
    spacing: Tokens.space.sm

    TextLabel {
        visible: root.title !== ""
        role: "caption"
        tone: "muted"
        font.weight: Font.Medium
        font.capitalization: Font.AllUppercase
        text: root.title
    }

    Surface {
        Layout.fillWidth: true
        implicitHeight: rowsColumn.implicitHeight + Tokens.space.xs * 2
        role: "card"
        radius: Tokens.radius.md
        verticalPadding: Tokens.space.xs

        ColumnLayout {
            id: rowsColumn

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0
        }
    }
}
