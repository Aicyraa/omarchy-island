pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

Item {
    id: root

    property bool open: false
    property string title: qsTr("Confirm")
    property string message: ""
    property string confirmText: qsTr("Confirm")
    property string cancelText: qsTr("Cancel")
    property bool destructive: false

    signal confirmed()
    signal cancelled()

    anchors.fill: parent
    visible: opacity > 0
    opacity: root.open ? 1.0 : 0.0
    z: 100

    Accessible.role: Accessible.Dialog
    Accessible.name: root.title

    onOpenChanged: {
        if (root.open)
            dialogCard.forceActiveFocus()
    }

    Behavior on opacity {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
    }

    Rectangle {
        anchors.fill: parent
        color: Tokens.color.scrim

        TapHandler {
            onTapped: root.cancelled()
        }
    }

    Surface {
        id: dialogCard

        anchors.centerIn: parent
        width: Math.min(parent.width - Tokens.space.xxl * 2, Tokens.size.panelSm)
        height: body.implicitHeight + Tokens.space.xl * 2
        role: "ground"
        radius: Tokens.radius.lg
        padding: Tokens.space.xl
        focus: root.open

        Keys.onEscapePressed: root.cancelled()
        Keys.onReturnPressed: root.confirmed()

        ColumnLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Tokens.space.md

            TextLabel {
                Layout.fillWidth: true
                role: "title"
                text: root.title
            }

            TextLabel {
                Layout.fillWidth: true
                visible: root.message !== ""
                singleLine: false
                role: "body"
                tone: "muted"
                text: root.message
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.space.xs
                spacing: Tokens.space.sm

                Item { Layout.fillWidth: true }

                Button {
                    text: root.cancelText
                    variant: "secondary"
                    onClicked: root.cancelled()
                }

                Button {
                    text: root.confirmText
                    variant: root.destructive ? "danger" : "primary"
                    onClicked: root.confirmed()
                }
            }
        }
    }
}
