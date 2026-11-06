import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Battery: charge, time remaining, draw, health, and the power profile.
// Keys: ←/→ change profile, 1-3 pick a profile, A toggle Stay awake.
Item {
  id: root
  focus: true
  property string hint: "←/→ or 1-3 profile · A stay awake · Esc close"
  readonly property var profiles: [
    { id: "power-saver", label: "Saver", icon: "moon" },
    { id: "balanced", label: "Balanced", icon: "battery" },
    { id: "performance", label: "Performance", icon: "bolt" }
  ]
  property string active: "balanced"

  function setProfile(i) {
    active = profiles[i].id
    // Omarchy remembers one profile for AC and one for battery.
    Cmd.run(["omarchy-powerprofiles-set", Power.charging ? "ac" : "battery", active])
  }
  readonly property int activeIndex: { for (var i = 0; i < profiles.length; i++) if (profiles[i].id === active) return i; return 1 }

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Left) { setProfile(Math.max(0, activeIndex - 1)); e.accepted = true }
    else if (e.key === Qt.Key_Right) { setProfile(Math.min(2, activeIndex + 1)); e.accepted = true }
    else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_3) { setProfile(e.key - Qt.Key_1); e.accepted = true }
    else if (e.key === Qt.Key_A) { Indicators.toggleStayAwake(); e.accepted = true }
  }
  Component.onCompleted: Indicators.refresh()

  Text { visible: !Power.present; anchors.centerIn: parent; textFormat: Text.PlainText
    text: "No battery in this machine"; color: Theme.textMuted; font.pixelSize: 14 }

  Item {
    visible: Power.present
    anchors.fill: parent

    // Big percentage with a ticking number (it animates between values).
    property real shown: Power.level * 100
    Behavior on shown { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 400; easing.type: Easing.OutCubic } }

    Text { x: 22; y: 14; textFormat: Text.PlainText; text: Math.round(parent.shown) + "%"
      color: Theme.text; font.pixelSize: 34; font.bold: true }
    Text { x: 24; y: 58; textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 12
      text: (Power.charging ? "Charging" : "On battery")
            + (Power.timeText(Power.secondsLeft) !== "" ? " · " + Power.timeText(Power.secondsLeft) + (Power.charging ? " to full" : " left") : "") }

    // Fill bar tracking the charge.
    Rectangle { x: 22; y: 84; width: root.width - 44; height: 12; radius: 6; color: Theme.surface
      Rectangle { height: parent.height; radius: 6; width: parent.width * Power.level
        color: Power.low ? Theme.danger : (Power.charging ? Theme.success : Theme.accent)
        Behavior on width { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 400; easing.type: Easing.OutCubic } } } }

    Row { x: 22; y: 108; spacing: 28
      Repeater {
        model: [ { k: "Draw", v: Power.watts.toFixed(1) + " W" },
                 { k: "Health", v: Power.health > 0 ? Math.round(Power.health) + "%" : "-" },
                 { k: "Stay awake", v: Indicators.stayAwake ? "On" : "Off" } ]
        delegate: Column { required property var modelData
          Text { textFormat: Text.PlainText; text: modelData.k; color: Theme.textMuted; font.pixelSize: 10 }
          Text { textFormat: Text.PlainText; text: modelData.v; color: Theme.text; font.pixelSize: 13; font.bold: true } }
      }
    }

    // Power profile segmented control.
    Row { x: 18; y: 160; spacing: 8
      Repeater {
        model: root.profiles
        delegate: Tile {
          required property var modelData
          required property int index
          width: (root.width - 36 - 16) / 3; height: 56
          icon: modelData.icon; title: modelData.label; subtitle: ""
          on: root.active === modelData.id
          keyHint: String(index + 1)
          onClicked: root.setProfile(index)
        }
      }
    }
  }

  Process {
    running: Power.present
    command: ["omarchy-powerprofiles-list", "--active-state"]
    stdout: StdioCollector { onStreamFinished: {
      text.split("\n").forEach(function (l) { var t = l.split("\t"); if (t.length >= 2 && t[1].trim() === "1") root.active = t[0] })
    } }
  }
}
