pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "../Theme"

Item {
    id: root

    // Either a bundled SVG name (resolved from Assets/icons/<name>.svg), a direct URL, or a glyph fallback.
    property string name: ""
    property url source: ""
    property string glyph: ""
    // Convenience auto-resolver: kebab-case [a-z0-9-]+ -> SVG icon name; otherwise -> glyph fallback.
    property string icon: ""

    property real size: Tokens.size.iconMd
    property string tone: "primary" // "primary" | "secondary" | "muted" | "disabled" | "accent" | "onAccent" | "success" | "warning" | "danger" | "info"
    property color customColor: "transparent"
    property bool tint: true
    property bool framed: false

    readonly property bool iconIsSvgName: root.icon !== "" && /^[a-z0-9-]+$/.test(root.icon)
    readonly property string effectiveName: root.name !== "" ? root.name : (root.iconIsSvgName ? root.icon : "")
    readonly property string effectiveGlyph: root.glyph !== "" ? root.glyph : (!root.iconIsSvgName ? root.icon : "")
    readonly property url resolvedSource: {
        if (root.source.toString() !== "")
            return root.source
        if (root.effectiveName !== "")
            return Qt.resolvedUrl("../Assets/icons/" + root.effectiveName + ".svg")
        return ""
    }
    readonly property bool useSvg: root.resolvedSource.toString() !== ""

    readonly property color resolvedColor: {
        if (root.customColor.a > 0)
            return root.customColor
        switch (root.tone) {
        case "secondary": return Tokens.color.textSecondary
        case "muted":     return Tokens.color.textMuted
        case "disabled":  return Tokens.color.textDisabled
        case "accent":    return Tokens.color.accent
        case "onAccent":  return Tokens.color.onAccent
        case "success":   return Tokens.color.success
        case "warning":   return Tokens.color.warning
        case "danger":    return Tokens.color.danger
        case "info":      return Tokens.color.info
        default:          return Tokens.color.text
        }
    }

    implicitWidth: root.framed ? root.size + Tokens.space.md : root.size
    implicitHeight: root.framed ? root.size + Tokens.space.md : root.size
    Accessible.ignored: true

    Rectangle {
        anchors.fill: parent
        visible: root.framed
        radius: Tokens.radius.sm
        color: Qt.rgba(root.resolvedColor.r, root.resolvedColor.g, root.resolvedColor.b, 0.14)
        border.width: Tokens.hairlineWidth
        border.color: Qt.rgba(root.resolvedColor.r, root.resolvedColor.g, root.resolvedColor.b, 0.28)
    }

    Item {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        visible: root.useSvg

        Image {
            id: svgImg

            anchors.fill: parent
            source: root.resolvedSource
            sourceSize: Qt.size(
                Math.max(1, Math.ceil(root.size * Tokens.dpr)),
                Math.max(1, Math.ceil(root.size * Tokens.dpr))
            )
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            asynchronous: false
            visible: !root.tint
        }

        MultiEffect {
            anchors.fill: svgImg
            source: svgImg
            visible: root.tint && svgImg.status === Image.Ready
            colorization: 1.0
            colorizationColor: root.resolvedColor
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !root.useSvg && root.effectiveGlyph !== ""
        text: root.effectiveGlyph
        font.family: Tokens.type.monoFamily
        font.pixelSize: Math.round(root.size)
        color: root.resolvedColor
    }
}
