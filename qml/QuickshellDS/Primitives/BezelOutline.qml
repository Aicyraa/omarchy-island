import QtQuick
import QtQuick.Shapes
import "../Theme"

Item {
    id: root

    property real bandHeight: 0
    property real corner: 0
    property real dropLeft: 0
    property real dropRight: 0
    property real dropDepth: 0
    property real dropRadius: 0
    property color color: Tokens.rimOf(Tokens.surfaceStyle)
    property int inset: 0

    readonly property real h: root.bandHeight
    readonly property real d: root.inset + 0.5
    readonly property bool dropped: root.dropDepth > 0
    readonly property real f: Math.min(Tokens.radius.notch * 2, root.dropDepth)
    readonly property real r: Math.max(0, Math.min(root.dropRadius, root.dropDepth, (root.dropRight - root.dropLeft) / 2))
    readonly property real ri: Math.max(0, root.r - root.d)

    anchors.fill: parent

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: Tokens.hairlineWidth
            strokeColor: root.color
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            startX: -root.d
            startY: root.h + root.corner

            PathArc {
                x: root.corner
                y: root.h - root.d
                radiusX: root.corner + root.d
                radiusY: root.corner + root.d
            }
            PathLine {
                x: root.dropped ? root.dropLeft - root.f : root.width - root.corner
                y: root.h - root.d
            }
            PathArc {
                x: root.dropped ? root.dropLeft + root.d : root.width - root.corner
                y: root.dropped ? root.h + root.f : root.h - root.d
                radiusX: root.f + root.d
                radiusY: root.f + root.d
            }
            PathLine {
                x: root.dropped ? root.dropLeft + root.d : root.width - root.corner
                y: root.dropped ? root.h + root.dropDepth - root.r : root.h - root.d
            }
            PathArc {
                x: root.dropped ? root.dropLeft + root.r : root.width - root.corner
                y: root.dropped ? root.h + root.dropDepth - root.d : root.h - root.d
                radiusX: root.ri
                radiusY: root.ri
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: root.dropped ? root.dropRight - root.r : root.width - root.corner
                y: root.dropped ? root.h + root.dropDepth - root.d : root.h - root.d
            }
            PathArc {
                x: root.dropped ? root.dropRight - root.d : root.width - root.corner
                y: root.dropped ? root.h + root.dropDepth - root.r : root.h - root.d
                radiusX: root.ri
                radiusY: root.ri
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: root.dropped ? root.dropRight - root.d : root.width - root.corner
                y: root.dropped ? root.h + root.f : root.h - root.d
            }
            PathArc {
                x: root.dropped ? root.dropRight + root.f : root.width - root.corner
                y: root.h - root.d
                radiusX: root.f + root.d
                radiusY: root.f + root.d
            }
            PathLine { x: root.width - root.corner; y: root.h - root.d }
            PathArc {
                x: root.width + root.d
                y: root.h + root.corner
                radiusX: root.corner + root.d
                radiusY: root.corner + root.d
            }
        }
    }
}
