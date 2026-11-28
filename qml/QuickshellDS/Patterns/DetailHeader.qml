import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"
import "../Components"

RowLayout {
    id: root

    property string title: ""
    property string detail: ""
    property string icon: ""
    property bool backable: true

    signal back()

    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(Tokens.px(40), titleCol.implicitHeight)
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

    Icon {
        visible: root.icon !== ""
        name: root.icon
        size: Tokens.size.iconMd
        tone: "accent"
        framed: true
    }

    ColumnLayout {
        id: titleCol

        Layout.fillWidth: true
        spacing: Tokens.space.xxs

        TextLabel {
            Layout.fillWidth: true
            role: "title"
            font.weight: Font.Medium
            text: root.title
        }

        TextLabel {
            Layout.fillWidth: true
            visible: root.detail !== ""
            role: "sm"
            tone: "muted"
            text: root.detail
        }
    }
}
