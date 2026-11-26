import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

ColumnLayout {
    id: root

    property string title: ""
    default property alias rows: list.data

    Layout.fillWidth: true
    spacing: Tokens.space.xs

    TextLabel {
        visible: root.title !== ""
        role: "caption"
        tone: "muted"
        font.weight: Font.Medium
        font.capitalization: Font.AllUppercase
        text: root.title
    }

    ColumnLayout {
        id: list

        Layout.fillWidth: true
        spacing: Tokens.space.xs
    }
}
