import QtQuick
import QtQuick.Shapes
import "../Theme"

Item {
    id: root

    property real shapeLeft: 0
    property real shapeRight: 0
    property real shapeHeight: 0
    property real radius: Tokens.radius.lg
    property color color: Tokens.rimOf(Tokens.surfaceStyle)
    property int inset: 0

    readonly property real filletSize: Tokens.radius.notch * 2
    readonly property real clampedRadius: Math.max(
        0,
        Math.min(root.radius, (root.shapeRight - root.shapeLeft) / 2, root.shapeHeight - root.filletSize)
    )
    readonly property real strokeOffset: root.inset + 0.5
    readonly property real innerCorner: Math.max(0, root.clampedRadius - root.strokeOffset)

    anchors.fill: parent

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: Tokens.hairlineWidth
            strokeColor: root.color
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            startX: root.shapeLeft - root.filletSize
            startY: -root.strokeOffset

            PathArc {
                x: root.shapeLeft + root.strokeOffset
                y: root.filletSize
                radiusX: root.filletSize + root.strokeOffset
                radiusY: root.filletSize + root.strokeOffset
            }
            PathLine { x: root.shapeLeft + root.strokeOffset; y: root.shapeHeight - root.clampedRadius }
            PathArc {
                x: root.shapeLeft + root.clampedRadius
                y: root.shapeHeight - root.strokeOffset
                radiusX: root.innerCorner
                radiusY: root.innerCorner
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.shapeRight - root.clampedRadius; y: root.shapeHeight - root.strokeOffset }
            PathArc {
                x: root.shapeRight - root.strokeOffset
                y: root.shapeHeight - root.clampedRadius
                radiusX: root.innerCorner
                radiusY: root.innerCorner
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.shapeRight - root.strokeOffset; y: root.filletSize }
            PathArc {
                x: root.shapeRight + root.filletSize
                y: -root.strokeOffset
                radiusX: root.filletSize + root.strokeOffset
                radiusY: root.filletSize + root.strokeOffset
            }
        }
    }
}
