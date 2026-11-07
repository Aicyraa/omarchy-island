import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Battery: charge, state, time remaining, and the power profile. Metrics with no
// data are hidden (never a dash). Keys: ←/→ or 1-3 pick a profile.
WidgetPanel {
  id: root
  preferredWidth: 480
  hint: "←/→ or 1-3 profile · Esc close"

  readonly property var profiles: [
    { id: "power-saver", label: "Saver", icon: "moon" },
    { id: "balanced", label: "Balanced", icon: "battery" },
    { id: "performance", label: "Perf", icon: "bolt" }
  ]
  property string active: "balanced"
  property real healthUpower: 0                // read once from `upower -i` when Quickshell has no value
  readonly property real healthPct: Power.health > 0 ? Power.health : healthUpower
  readonly property int activeIndex: { for (var i = 0; i < profiles.length; i++) if (profiles[i].id === active) return i; return 1 }

  function setProfile(i) {
    active = profiles[i].id
    // Omarchy remembers one profile for AC and one for battery.
    Cmd.run(["omarchy-powerprofiles-set", Power.charging || Power.full ? "ac" : "battery", active])
  }
  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Left) { setProfile(Math.max(0, activeIndex - 1)); e.accepted = true }
    else if (e.key === Qt.Key_Right) { setProfile(Math.min(2, activeIndex + 1)); e.accepted = true }
    else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_3) { setProfile(e.key - Qt.Key_1); e.accepted = true }
  }

  Text { visible: !Power.present; textFormat: Text.PlainText
    text: "No battery in this machine"; color: Theme.textMuted; font.pixelSize: 14 }

  // Header line: the big percentage and its state on the left; "Charging at"/"Draw" and "Health" on the same line, on the right,
  // as two little cards. Metrics with no data are not drawn.
  Item {
    visible: Power.present; width: parent.width; height: 56
    property real shown: Power.level * 100
    Behavior on shown { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 400; easing.type: Easing.OutCubic } }
    Column { anchors.verticalCenter: parent.verticalCenter; spacing: 1
      Text { textFormat: Text.PlainText; text: Math.round(parent.parent.shown) + "%"; color: Theme.text; font.pixelSize: 34; font.weight: Theme.weightStrong }
      Text { textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 12
        text: Power.stateText + (Power.timeText(Power.secondsLeft) !== ""
              ? " · " + Power.timeText(Power.secondsLeft) + (Power.charging ? " to full" : " left") : "") } }
    Row { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
      Repeater {
        model: {
          var m = []
          if (Power.watts > 0.05) m.push({ k: Power.charging ? "Charging at" : "Draw", v: Power.watts.toFixed(1) + " W", ic: "bolt" })
          if (root.healthPct > 0) m.push({ k: "Health", v: Math.round(root.healthPct) + "%", ic: "heart" })
          return m
        }
        delegate: Rectangle { required property var modelData
          antialiasing: true; height: 48; width: Math.max(88, cardCol.implicitWidth + 2 * Theme.s12); radius: Theme.tileRadius - 4; color: Theme.surface
          Column { id: cardCol; anchors.centerIn: parent; spacing: 1
            Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText; text: modelData.k; color: Theme.textMuted; font.pixelSize: 11 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText; text: modelData.v; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightLabel } } } }
    }
  }
  Rectangle { antialiasing: true; visible: Power.present; width: parent.width; height: 12; radius: 6; color: Theme.surface
    Rectangle { antialiasing: true; height: parent.height; radius: 6; width: Math.max(12, parent.width * Power.level)
      color: Power.low ? Theme.dangerInk : (Power.charging ? Theme.successInk : Theme.accentFill)
      Behavior on width { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 400; easing.type: Easing.OutCubic } } } }

  // Three equal pills; short labels that never truncate.
  Row {
    visible: Power.present; width: parent.width; spacing: Theme.s8
    Repeater {
      model: root.profiles
      delegate: Tile {
        required property var modelData
        required property int index
        width: (parent.width - 2 * Theme.s8) / 3; height: 48
        iconCircle: false
        icon: modelData.icon; title: modelData.label
        on: root.active === modelData.id
        onClicked: root.setProfile(index)
      }
    }
  }

  Process {
    running: Power.present && Power.health <= 0
    command: ["bash", "-c", "upower -i $(upower -e | grep -i bat | head -1) | grep -E '^ *capacity:'"]
    stdout: StdioCollector { onStreamFinished: { var m = /([\d.]+)\s*%/.exec(text); if (m) root.healthUpower = parseFloat(m[1]) } }
  }
  Process {
    running: Power.present
    command: ["omarchy-powerprofiles-list", "--active-state"]
    stdout: StdioCollector { onStreamFinished: {
      text.split("\n").forEach(function (l) { var t = l.split("\t"); if (t.length >= 2 && t[1].trim() === "1") root.active = t[0] })
    } }
  }
}
