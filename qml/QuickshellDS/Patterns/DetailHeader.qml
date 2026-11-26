import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"
import "../Components"

RowLayout {
    id: root

    property string title: ""
    property string detail: ""
    property bool backable: true

    signal back()

    Layout.fillWidth: true
    Layout.preferredHeight: Tokens.px(38)
    spacing: Tokens.space.md

    Button {
        visible: root.backable
        icon: "chevron-left"
        variant: "ghost"
        shape: "rounded"
        size: "sm"
        accessibleLabel: qsTr("Back")
        onClicked: root.back()
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.space.xxs

        TextLabel {
            Layout.fillWidth: true
            role: "subtitle"
            font.weight: Font.Medium
            text: root.title
        }

        TextLabel {
            Layout.fillWidth: true
            visible: root.detail !== ""
            role: "caption"
            tone: "muted"
            text: root.detail
        }
    }
}
