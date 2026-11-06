import QtQuick
import ".."

// Home: the SUPER+CTRL+M widget is the hover form, pinned. Same component, so the two can never drift apart.
// (It closes on Esc, a click outside, or inactivity, like any widget.)
HoverPreview {
  focus: true
}
