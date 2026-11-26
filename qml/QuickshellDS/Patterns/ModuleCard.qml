import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

ColumnLayout {
    id: root

    property alias mark: markSlot.data
    property string title: ""
    property string subtitle: ""
    property string figure: ""
    property string figureTone: "primary"
    default property alias rows: body.data

    spacing: Tokens.space.md

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.px(44)
        spacing: Tokens.space.md

        Item {
            id: markSlot

            Layout.preferredWidth: Tokens.px(44)
            Layout.preferredHeight: Tokens.px(44)
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
                visible: root.subtitle !== ""
                role: "sm"
                tone: "muted"
                text: root.subtitle
            }
        }

        TextLabel {
            visible: root.figure !== ""
            role: "h2"
            tabular: true
            tone: root.figureTone
            text: root.figure
        }
    }

    ColumnLayout {
        id: body

        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: children.length > 0
        spacing: Tokens.space.sm
    }
}
