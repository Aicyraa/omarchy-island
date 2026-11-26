import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"
import "../Components"

Item {
    id: root

    property string label: ""
    property string description: ""
    property bool showDivider: true
    default property alias control: controlSlot.data

    Layout.fillWidth: true
    implicitHeight: Math.max(Tokens.px(48), body.implicitHeight + Tokens.space.lg)

    Separator {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.showDivider
    }

    RowLayout {
        id: body

        anchors.fill: parent
        anchors.leftMargin: Tokens.space.xl
        anchors.rightMargin: Tokens.space.xl
        spacing: Tokens.space.md

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Tokens.space.xxs

            TextLabel {
                Layout.fillWidth: true
                role: "body"
                text: root.label
            }

            TextLabel {
                Layout.fillWidth: true
                visible: root.description !== ""
                role: "sm"
                tone: "muted"
                text: root.description
            }
        }

        Row {
            id: controlSlot

            Layout.alignment: Qt.AlignVCenter
            spacing: Tokens.space.sm
        }
    }
}
