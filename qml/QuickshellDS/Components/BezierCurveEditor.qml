pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../Theme"
import "../Primitives"

ColumnLayout {
    id: root

    property var curve: [0.05, 0.92, 0.12, 1.04]
    property real durationMs: 420
    property bool interactive: true

    signal curveEdited(var nextCurve)

    readonly property real yMin: -0.25
    readonly property real yMax: 1.45

    readonly property real x1: curve && curve.length === 4 ? Number(curve[0]) : 0.05
    readonly property real y1: curve && curve.length === 4 ? Number(curve[1]) : 0.92
    readonly property real x2: curve && curve.length === 4 ? Number(curve[2]) : 0.12
    readonly property real y2: curve && curve.length === 4 ? Number(curve[3]) : 1.04

    property real previewTime: 1.0
    property real previewProgress: 1.0

    readonly property var presets: [
        { id: "snappy", label: qsTr("Snappy"), curve: [0.05, 0.92, 0.12, 1.04] },
        { id: "expo",   label: qsTr("Expo"),   curve: [0.16, 1.00, 0.30, 1.00] },
        { id: "bouncy", label: qsTr("Bouncy"), curve: [0.18, 1.32, 0.32, 1.00] },
        { id: "smooth", label: qsTr("Smooth"), curve: [0.40, 0.00, 0.20, 1.00] },
        { id: "linear", label: qsTr("Linear"), curve: [0.00, 0.00, 1.00, 1.00] }
    ]

    readonly property string activePresetId: {
        for (let i = 0; i < root.presets.length; ++i) {
            const p = root.presets[i].curve
            if (Math.abs(root.x1 - p[0]) < 0.015
                && Math.abs(root.y1 - p[1]) < 0.015
                && Math.abs(root.x2 - p[2]) < 0.015
                && Math.abs(root.y2 - p[3]) < 0.015)
                return root.presets[i].id
        }
        return "custom"
    }

    function fmt(v: real): string {
        return Number(v).toFixed(2)
    }

    function updateHandle(which: int, px: real, py: real): void {
        if (!root.interactive || plotArea.width <= 0 || plotArea.height <= 0)
            return
        const nxVal = Math.round(Math.max(0.0, Math.min(1.0, px / plotArea.width)) * 100) / 100
        const tY = 1.0 - (py / plotArea.height)
        const rawY = root.yMin + tY * (root.yMax - root.yMin)
        const nyVal = Math.round(Math.max(root.yMin, Math.min(root.yMax, rawY)) * 100) / 100
        if (which === 1)
            root.curveEdited([nxVal, nyVal, root.x2, root.y2])
        else
            root.curveEdited([root.x1, root.y1, nxVal, nyVal])
    }

    function replayPreview(): void {
        if (!root.interactive) {
            previewAnim.stop()
            root.previewTime = 1.0
            root.previewProgress = 1.0
            return
        }
        previewAnim.restart()
    }

    spacing: Tokens.space.md

    ParallelAnimation {
        id: previewAnim

        NumberAnimation {
            target: root
            property: "previewTime"
            from: 0.0
            to: 1.0
            duration: Math.max(120, Math.round(root.durationMs))
            easing.type: Easing.Linear
        }

        NumberAnimation {
            target: root
            property: "previewProgress"
            from: 0.0
            to: 1.0
            duration: Math.max(120, Math.round(root.durationMs))
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [root.x1, root.y1, root.x2, root.y2, 1.0, 1.0]
        }
    }

    // ── PRESET STRIP ────────────────────────────────────────────────────────

    TabStrip {
        Layout.fillWidth: true
        stretch: true
        enabled: root.interactive
        accessibleLabel: qsTr("Animation curve presets")
        tabs: root.presets
        current: root.activePresetId
        onPicked: function (id) {
            for (let i = 0; i < root.presets.length; ++i) {
                if (root.presets[i].id === id) {
                    root.curveEdited(root.presets[i].curve.slice())
                    Qt.callLater(root.replayPreview)
                    break
                }
            }
        }
    }

    // ── GRAPH + UNIFIED PREVIEW & CONTROLS ──────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.space.lg

        // Left: Borderless, Wider Interactive Cubic-Bezier Plot
        Item {
            id: graphHost

            Layout.fillWidth: true
            Layout.minimumWidth: Tokens.px(280)
            Layout.preferredHeight: Tokens.px(228)

            Item {
                id: plotArea

                property int draggingHandle: 0
                property int hoveredHandle: 0

                anchors.fill: parent
                anchors.leftMargin: Tokens.px(18)
                anchors.rightMargin: Tokens.px(12)
                anchors.topMargin: Tokens.px(26)
                anchors.bottomMargin: Tokens.px(18)

                function nx(x: real): real {
                    return x * plotArea.width
                }

                function ny(y: real): real {
                    const t = (y - root.yMin) / (root.yMax - root.yMin)
                    return (1.0 - t) * plotArea.height
                }

                function nearestHandle(px: real, py: real, maxDist: real): int {
                    const dx1 = px - plotArea.nx(root.x1)
                    const dy1 = py - plotArea.ny(root.y1)
                    const d1 = Math.sqrt(dx1 * dx1 + dy1 * dy1)
                    const dx2 = px - plotArea.nx(root.x2)
                    const dy2 = py - plotArea.ny(root.y2)
                    const d2 = Math.sqrt(dx2 * dx2 + dy2 * dy2)
                    const best = Math.min(d1, d2)
                    if (best > maxDist)
                        return 0
                    return d1 <= d2 ? 1 : 2
                }

                // 0..1 unit square guide
                Rectangle {
                    x: plotArea.nx(0)
                    y: plotArea.ny(1)
                    width: Math.max(0, plotArea.nx(1) - plotArea.nx(0))
                    height: Math.max(0, plotArea.ny(0) - plotArea.ny(1))
                    color: Qt.alpha(Tokens.color.text, 0.03)
                    border.width: 1
                    border.color: Tokens.color.border

                    Repeater {
                        model: [0.25, 0.5, 0.75]

                        delegate: Item {
                            id: gridLine

                            required property real modelData

                            anchors.fill: parent

                            Rectangle {
                                x: parent.width * gridLine.modelData
                                y: 0
                                width: 1
                                height: parent.height
                                color: Tokens.color.hairline
                            }

                            Rectangle {
                                x: 0
                                y: parent.height * gridLine.modelData
                                width: parent.width
                                height: 1
                                color: Tokens.color.hairline
                            }
                        }
                    }
                }

                // Axis corner labels
                TextLabel {
                    x: plotArea.nx(0) - Tokens.px(12)
                    y: plotArea.ny(0) - Tokens.px(6)
                    role: "caption"
                    tone: "muted"
                    text: "0"
                    textFormat: Text.PlainText
                }

                TextLabel {
                    x: plotArea.nx(0) - Tokens.px(12)
                    y: plotArea.ny(1) - Tokens.px(6)
                    role: "caption"
                    tone: "muted"
                    text: "1"
                    textFormat: Text.PlainText
                }

                TextLabel {
                    x: plotArea.nx(1) - Tokens.px(3)
                    y: plotArea.ny(0) + Tokens.px(4)
                    role: "caption"
                    tone: "muted"
                    text: "1"
                    textFormat: Text.PlainText
                }

                // Vector curves & tangent handles
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    // Linear reference diagonal
                    ShapePath {
                        strokeColor: Tokens.color.hairline
                        strokeWidth: 1
                        fillColor: "transparent"
                        startX: plotArea.nx(0)
                        startY: plotArea.ny(0)

                        PathLine {
                            x: plotArea.nx(1)
                            y: plotArea.ny(1)
                        }
                    }

                    // Tangent 1: (0,0) -> P1
                    ShapePath {
                        strokeColor: Qt.alpha(Tokens.color.accent, 0.55)
                        strokeWidth: 1.5
                        fillColor: "transparent"
                        startX: plotArea.nx(0)
                        startY: plotArea.ny(0)

                        PathLine {
                            x: plotArea.nx(root.x1)
                            y: plotArea.ny(root.y1)
                        }
                    }

                    // Tangent 2: (1,1) -> P2
                    ShapePath {
                        strokeColor: Qt.alpha(Tokens.color.info, 0.55)
                        strokeWidth: 1.5
                        fillColor: "transparent"
                        startX: plotArea.nx(1)
                        startY: plotArea.ny(1)

                        PathLine {
                            x: plotArea.nx(root.x2)
                            y: plotArea.ny(root.y2)
                        }
                    }

                    // Main cubic-bezier curve
                    ShapePath {
                        strokeColor: Tokens.color.accent
                        strokeWidth: 2.5
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        startX: plotArea.nx(0)
                        startY: plotArea.ny(0)

                        PathCubic {
                            control1X: plotArea.nx(root.x1)
                            control1Y: plotArea.ny(root.y1)
                            control2X: plotArea.nx(root.x2)
                            control2Y: plotArea.ny(root.y2)
                            x: plotArea.nx(1)
                            y: plotArea.ny(1)
                        }
                    }
                }

                // Fixed endpoints (0,0) and (1,1)
                Rectangle {
                    width: Tokens.px(6)
                    height: Tokens.px(6)
                    radius: width / 2
                    x: plotArea.nx(0) - width / 2
                    y: plotArea.ny(0) - height / 2
                    color: Tokens.color.textMuted
                }

                Rectangle {
                    width: Tokens.px(6)
                    height: Tokens.px(6)
                    radius: width / 2
                    x: plotArea.nx(1) - width / 2
                    y: plotArea.ny(1) - height / 2
                    color: Tokens.color.textMuted
                }

                // Live animated trace dot along the curve
                Rectangle {
                    visible: previewAnim.running
                    width: Tokens.px(8)
                    height: Tokens.px(8)
                    radius: width / 2
                    x: plotArea.nx(root.previewTime) - width / 2
                    y: plotArea.ny(root.previewProgress) - height / 2
                    color: Tokens.color.text
                    border.width: 2
                    border.color: Tokens.color.accent
                }

                // Handle P1
                Rectangle {
                    id: handleP1

                    readonly property bool active: plotArea.draggingHandle === 1 || plotArea.hoveredHandle === 1

                    width: active ? Tokens.px(14) : Tokens.px(12)
                    height: width
                    radius: width / 2
                    x: plotArea.nx(root.x1) - width / 2
                    y: plotArea.ny(root.y1) - height / 2
                    color: Tokens.color.accent
                    border.width: 2
                    border.color: Tokens.color.bg
                }

                // Handle P2
                Rectangle {
                    id: handleP2

                    readonly property bool active: plotArea.draggingHandle === 2 || plotArea.hoveredHandle === 2

                    width: active ? Tokens.px(14) : Tokens.px(12)
                    height: width
                    radius: width / 2
                    x: plotArea.nx(root.x2) - width / 2
                    y: plotArea.ny(root.y2) - height / 2
                    color: Tokens.color.info
                    border.width: 2
                    border.color: Tokens.color.bg
                }

                // Stationary plot-wide drag surface (prevents moving-item drag glitches & Flickable stealing)
                MouseArea {
                    id: plotMouse

                    z: 10
                    anchors.fill: parent
                    anchors.margins: -Tokens.px(12)
                    hoverEnabled: true
                    preventStealing: true
                    enabled: root.interactive
                    cursorShape: plotArea.draggingHandle > 0
                        ? Qt.ClosedHandCursor
                        : (plotArea.hoveredHandle > 0 ? Qt.OpenHandCursor : Qt.CrossCursor)

                    onPressed: function (mouse) {
                        const pt = mapToItem(plotArea, mouse.x, mouse.y)
                        plotArea.draggingHandle = plotArea.nearestHandle(pt.x, pt.y, 9999)
                        if (plotArea.draggingHandle > 0)
                            root.updateHandle(plotArea.draggingHandle, pt.x, pt.y)
                    }

                    onPositionChanged: function (mouse) {
                        const pt = mapToItem(plotArea, mouse.x, mouse.y)
                        if (pressed && plotArea.draggingHandle > 0) {
                            root.updateHandle(plotArea.draggingHandle, pt.x, pt.y)
                        } else {
                            plotArea.hoveredHandle = plotArea.nearestHandle(pt.x, pt.y, Tokens.px(24))
                        }
                    }

                    onReleased: {
                        plotArea.draggingHandle = 0
                        root.replayPreview()
                    }

                    onCanceled: {
                        plotArea.draggingHandle = 0
                    }

                    onExited: {
                        if (!pressed)
                            plotArea.hoveredHandle = 0
                    }
                }
            }
        }

        // Right: Unified Live Preview + Coordinates + Replay Card
        Surface {
            Layout.preferredWidth: Tokens.px(268)
            Layout.preferredHeight: Math.max(graphHost.Layout.preferredHeight, panelCol.implicitHeight + verticalPadding * 2)
            verticalPadding: Tokens.space.md
            horizontalPadding: Tokens.space.md
            role: "card"
            radius: Tokens.radius.md

            ColumnLayout {
                id: panelCol

                anchors.fill: parent
                spacing: Tokens.space.md

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.sm

                    TextLabel {
                        Layout.fillWidth: true
                        role: "caption"
                        tone: "muted"
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        text: qsTr("Live Preview")
                        textFormat: Text.PlainText
                    }

                    Badge {
                        visible: root.activePresetId === "custom"
                        text: qsTr("Custom")
                        tone: "muted"
                    }

                    TextLabel {
                        role: "mono"
                        tone: "muted"
                        text: qsTr("%1 ms").arg(Math.round(root.durationMs))
                        textFormat: Text.PlainText
                    }
                }

                Rectangle {
                    id: previewTrack

                    Layout.fillWidth: true
                    height: Tokens.px(28)
                    radius: Tokens.radius.pill
                    color: Tokens.color.bg
                    border.width: 1
                    border.color: Tokens.color.border

                    TapHandler {
                        enabled: root.interactive
                        onTapped: root.replayPreview()
                    }

                    // Target 1.0 marker tick
                    Rectangle {
                        x: Math.round(previewTrack.width * 0.80)
                        y: Tokens.px(5)
                        width: 1
                        height: previewTrack.height - Tokens.px(10)
                        color: Tokens.color.hairline
                    }

                    // Morphing mini-pill
                    Rectangle {
                        readonly property real minW: Tokens.px(32)
                        readonly property real targetW: Math.max(minW, previewTrack.width * 0.80 - Tokens.px(8))

                        x: Tokens.px(4)
                        y: Tokens.px(4)
                        height: previewTrack.height - Tokens.px(8)
                        radius: height / 2
                        width: Math.max(Tokens.px(18), Math.min(previewTrack.width - Tokens.px(8), minW + (targetW - minW) * root.previewProgress))
                        color: Tokens.color.accent
                    }
                }

                Separator {
                    Layout.fillWidth: true
                }

                TextLabel {
                    Layout.fillWidth: true
                    role: "caption"
                    font.family: Tokens.type.monoFamily
                    tabular: true
                    tone: "primary"
                    text: "cubic-bezier("
                        + root.fmt(root.x1) + ", "
                        + root.fmt(root.y1) + ", "
                        + root.fmt(root.x2) + ", "
                        + root.fmt(root.y2) + ")"
                    textFormat: Text.PlainText
                }

                Item {
                    Layout.fillHeight: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.sm

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.xs

                        RowLayout {
                            spacing: Tokens.space.xs

                            Rectangle {
                                width: Tokens.px(8)
                                height: Tokens.px(8)
                                radius: width / 2
                                color: Tokens.color.accent
                            }

                            TextLabel {
                                role: "caption"
                                tabular: true
                                tone: "muted"
                                text: "P1 (" + root.fmt(root.x1) + ", " + root.fmt(root.y1) + ")"
                                textFormat: Text.PlainText
                            }
                        }

                        RowLayout {
                            spacing: Tokens.space.xs

                            Rectangle {
                                width: Tokens.px(8)
                                height: Tokens.px(8)
                                radius: width / 2
                                color: Tokens.color.info
                            }

                            TextLabel {
                                role: "caption"
                                tabular: true
                                tone: "muted"
                                text: "P2 (" + root.fmt(root.x2) + ", " + root.fmt(root.y2) + ")"
                                textFormat: Text.PlainText
                            }
                        }
                    }

                    Button {
                        Layout.alignment: Qt.AlignVCenter
                        text: qsTr("Replay")
                        icon: "play"
                        variant: "secondary"
                        size: "sm"
                        enabled: root.interactive
                        onClicked: root.replayPreview()
                    }
                }
            }
        }
    }
}
