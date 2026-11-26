import QtQuick
import "../Theme"
import "../Primitives"

Surface {
    id: root

    property bool bare: false

    role: root.bare ? "bare" : "card"
    radius: Tokens.radius.md
    verticalPadding: Tokens.space.lg
    horizontalPadding: Tokens.space.xl
}
