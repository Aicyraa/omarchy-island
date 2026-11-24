import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"
import "../Components"

Surface {
    id: root

    property string icon: ""
    property string label: ""
    property real progress: -1 // < 0 hides progress bar

    role: "ground"
    radius: Tokens.radius.pill
    implicitWidth: Tokens.px(260)
    implicitHeight: Tokens.size.controlLg
    horizontalPadding: Tokens.space.xl
    verticalPadding: Tokens.space.sm

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.space.md

        Icon {
            visible: root.icon !== ""
            size: Tokens.size.iconMd
            tone: "accent"
            icon: root.icon
        }

        TextLabel {
            Layout.fillWidth: true
            role: "body"
            font.weight: Font.Medium
            text: root.label
        }

        UsageBar {
            visible: root.progress >= 0
            Layout.preferredWidth: Tokens.px(88)
            progress: Math.max(0, root.progress)
        }
    }
}
