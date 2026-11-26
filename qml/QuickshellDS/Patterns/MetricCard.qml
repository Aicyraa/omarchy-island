import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"
import "../Components"

Card {
    id: root

    property string label: ""
    property string icon: ""
    property string value: ""
    property string unit: ""
    property string subtext: ""
    property string delta: ""
    property string deltaTone: "neutral" // "neutral" | "accent" | "success" | "warning" | "danger" | "info"
    default property alias visual: visualSlot.data

    implicitWidth: Tokens.px(240)
    implicitHeight: layout.implicitHeight + root.verticalPadding * 2

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.space.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.space.sm

            Icon {
                visible: root.icon !== ""
                size: Tokens.size.iconSm
                tone: "accent"
                framed: true
                icon: root.icon
            }

            TextLabel {
                Layout.fillWidth: true
                role: "caption"
                tone: "muted"
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                text: root.label
            }

            Badge {
                visible: root.delta !== ""
                text: root.delta
                tone: root.deltaTone
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.space.xs

            TextLabel {
                role: "h1"
                tabular: true
                text: root.value
            }

            TextLabel {
                visible: root.unit !== ""
                Layout.alignment: Qt.AlignBaseline
                role: "sm"
                tone: "muted"
                text: root.unit
            }

            Item { Layout.fillWidth: true }
        }

        Item {
            id: visualSlot

            Layout.fillWidth: true
            implicitHeight: childrenRect.height
            visible: children.length > 0
        }

        TextLabel {
            Layout.fillWidth: true
            visible: root.subtext !== ""
            role: "sm"
            tone: "muted"
            text: root.subtext
        }
    }
}
