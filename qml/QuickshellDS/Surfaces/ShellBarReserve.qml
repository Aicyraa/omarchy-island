import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme"

PanelWindow {
    id: root

    property bool hidden: false
    property real barMargin: Tokens.space.lg

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 1
    color: "transparent"
    exclusiveZone: root.hidden ? 0 : Math.round(root.barMargin + Tokens.size.barHeight)
    WlrLayershell.layer: WlrLayer.Background
    mask: Region {}
}
