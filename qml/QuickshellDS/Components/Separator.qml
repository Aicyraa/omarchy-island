import QtQuick
import QtQuick.Layouts
import "../Theme"

Rectangle {
    id: root

    property int orientation: Qt.Horizontal

    Layout.fillWidth: root.orientation === Qt.Horizontal
    Layout.fillHeight: root.orientation === Qt.Vertical
    implicitWidth: root.orientation === Qt.Horizontal ? Tokens.px(100) : Tokens.hairlineWidth
    implicitHeight: root.orientation === Qt.Horizontal ? Tokens.hairlineWidth : Tokens.px(24)
    color: Tokens.color.hairline
}
