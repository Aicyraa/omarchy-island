import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

ColumnLayout {
    id: root

    property string icon: "sparkles"
    property string title: qsTr("Nothing here")
    property string description: ""

    spacing: Tokens.space.sm

    Icon {
        Layout.alignment: Qt.AlignHCenter
        size: Tokens.size.iconXl
        tone: "muted"
        framed: true
        icon: root.icon
    }

    TextLabel {
        Layout.alignment: Qt.AlignHCenter
        role: "subtitle"
        tone: "primary"
        text: root.title
    }

    TextLabel {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: Tokens.px(260)
        visible: root.description !== ""
        horizontalAlignment: Text.AlignHCenter
        singleLine: false
        role: "sm"
        tone: "muted"
        text: root.description
    }
}
