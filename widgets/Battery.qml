import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Battery: asymmetrical Apple-style dashboard — dominant charge hero card on the left,
// stacked Wattage + Health cards on the right, and a unified segmented power-profile dock below.
// Keys: ←/→ or 1-3 pick a profile, Esc close.
WidgetPanel {
  id: root
  preferredWidth: 540
  hint: "←/→ or 1-3 profile · Esc close"

  readonly property var profiles: [
    { id: "power-saver", label: "Saver", icon: "moon" },
    { id: "balanced", label: "Balanced", icon: "battery" },
    { id: "performance", label: "Performance", icon: "bolt" }
  ]
  property string active: "balanced"
  property real healthUpower: 0
  readonly property real healthPct: Power.health > 0 ? Power.health : healthUpower
  readonly property int activeIndex: {
    for (var i = 0; i < profiles.length; i++) if (profiles[i].id === active) return i
    return 1
  }
  readonly property color chargeColor: Power.low ? Theme.dangerInk : (Power.charging || Power.full ? Theme.successInk : Theme.accentFill)

  function setProfile(i) {
    active = profiles[i].id
    Cmd.run(["omarchy-powerprofiles-set", Power.charging || Power.full ? "ac" : "battery", active])
  }
  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Left) { setProfile(Math.max(0, activeIndex - 1)); e.accepted = true }
    else if (e.key === Qt.Key_Right) { setProfile(Math.min(2, activeIndex + 1)); e.accepted = true }
    else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_3) { setProfile(e.key - Qt.Key_1); e.accepted = true }
  }

  Label {
    visible: !Power.present
    text: "No battery in this machine"; color: Theme.textMuted; font.pixelSize: Theme.typeTitle
  }

  // ---- top asymmetrical split: hero charge card (~60%) + offset metrics (~40%) ----
  readonly property real heroW: Math.round((width - 2 * pad - Theme.s12) * 0.60)
  readonly property real sideW: (width - 2 * pad - Theme.s12) - heroW

  Row {
    visible: Power.present
    width: parent.width; spacing: Theme.s12

    // Left hero card: big percentage, state pill, time remaining, animated charge gauge.
    SmoothRect {
      width: root.heroW; height: 118; radius: Theme.tileRadius + 2; color: Theme.surface
      property real shown: Power.level * 100
      Behavior on shown { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 400; easing.type: Easing.OutCubic } }

      Column {
        anchors.fill: parent; anchors.margins: Theme.s16; spacing: Theme.s8
        Item {
          width: parent.width; height: 48
          Label {
            id: pctText; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            mono: true; text: Math.round(parent.parent.parent.shown) + "%"
            color: Theme.text; font.pixelSize: 40; font.weight: Theme.weightStrong
          }
          SmoothRect {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            height: 24; width: stateRow.implicitWidth + 16; radius: 12
            color: Power.charging || Power.full
              ? Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.22)
              : (Power.low ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.22) : Theme.surfaceRaised)
            Row {
              id: stateRow; anchors.centerIn: parent; spacing: 4
              Icon {
                visible: Power.charging || Power.low; name: Power.charging ? "bolt" : "alert"; size: 12
                color: Power.charging ? Theme.successInk : Theme.dangerInk; anchors.verticalCenter: parent.verticalCenter
              }
              Label {
                text: Power.stateText
                color: Power.charging || Power.full ? Theme.successInk : (Power.low ? Theme.dangerInk : Theme.textMuted)
                font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel; anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }

        // Animated charge bar inside the hero card.
        SmoothRect {
          width: parent.width; height: 10; radius: 5
          color: Theme.mix(Theme.surface, Theme.text, 0.12)
          SmoothRect {
            height: parent.height; radius: 5
            width: Math.max(10, parent.width * Math.max(0, Math.min(1, Power.level)))
            color: root.chargeColor
            Behavior on width { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 400; easing.type: Easing.OutCubic } }
          }
        }

        Label {
          width: parent.width; elide: Text.ElideRight
          color: Theme.textMuted; font.pixelSize: Theme.typeLabel
          text: Power.timeText(Power.secondsLeft) !== ""
            ? (Power.timeText(Power.secondsLeft) + (Power.charging ? " until full" : " remaining"))
            : (Power.full ? "Fully charged · AC power" : (Power.charging ? "Connected to AC power" : "Running on battery"))
        }
      }
    }

    // Right offset column: stacked Wattage and Health cards.
    Column {
      width: root.sideW; spacing: Theme.s8
      SmoothRect {
        width: parent.width; height: 55; radius: Theme.tileRadius; color: Theme.surface
        Row {
          anchors.fill: parent; anchors.leftMargin: Theme.s12; anchors.rightMargin: Theme.s12; spacing: Theme.s12
          SmoothRect {
            width: 32; height: 32; radius: Theme.radiusChip; anchors.verticalCenter: parent.verticalCenter
            color: Theme.mix(Theme.surface, Theme.accentFill, 0.16)
            Icon { anchors.centerIn: parent; name: "bolt"; size: Theme.iconSm; color: Power.charging ? Theme.successInk : Theme.accentInk }
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter; spacing: 1
            Label {
              text: Power.charging ? "Charging at" : "Power draw"
              color: Theme.textMuted; font.pixelSize: Theme.typeCaption
            }
            Label {
              mono: true
              text: Power.watts > 0.05 ? (Power.watts.toFixed(1) + " W") : (Power.full ? "Idle" : "—")
              color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong
            }
          }
        }
      }
      SmoothRect {
        width: parent.width; height: 55; radius: Theme.tileRadius; color: Theme.surface
        Row {
          anchors.fill: parent; anchors.leftMargin: Theme.s12; anchors.rightMargin: Theme.s12; spacing: Theme.s12
          SmoothRect {
            width: 32; height: 32; radius: Theme.radiusChip; anchors.verticalCenter: parent.verticalCenter
            color: Theme.mix(Theme.surface, Theme.successInk, 0.16)
            Icon { anchors.centerIn: parent; name: "battery"; size: Theme.iconSm; color: Theme.successInk }
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter; spacing: 1
            Label { text: "Battery health"; color: Theme.textMuted; font.pixelSize: Theme.typeCaption }
            Label {
              mono: true
              text: root.healthPct > 0 ? (Math.round(root.healthPct) + "%") : "Good"
              color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong
            }
          }
        }
      }
    }
  }

  // ---- unified segmented power-profile dock with sliding accent pill ----
  SmoothRect {
    id: segTrack
    visible: Power.present
    width: parent.width; height: 48; radius: 24; color: Theme.surface
    readonly property int padIn: 4
    readonly property real segW: (width - 2 * padIn) / root.profiles.length

    SmoothRect {
      id: sliderPill
      y: segTrack.padIn; height: segTrack.height - 2 * segTrack.padIn
      width: segTrack.segW; radius: height / 2
      x: segTrack.padIn + root.activeIndex * segTrack.segW
      color: Theme.accentFill
      Behavior on x { enabled: !IslandState.reducedMotion; SpringAnimation { spring: 5.0; damping: 0.48; epsilon: 0.25 } }
    }

    Row {
      x: segTrack.padIn; y: segTrack.padIn
      width: segTrack.width - 2 * segTrack.padIn; height: segTrack.height - 2 * segTrack.padIn
      Repeater {
        model: root.profiles
        delegate: Item {
          required property var modelData
          required property int index
          readonly property bool isOn: root.active === modelData.id
          width: segTrack.segW; height: parent.height
          Row {
            anchors.centerIn: parent; spacing: 6
            Icon {
              name: modelData.icon; size: Theme.iconSm
              color: parent.parent.isOn ? Theme.accentText : Theme.textMuted
              anchors.verticalCenter: parent.verticalCenter
            }
            Label {
              text: modelData.label
              color: parent.parent.isOn ? Theme.accentText : Theme.text
              font.pixelSize: Theme.typeBody; font.weight: parent.parent.isOn ? Theme.weightStrong : Theme.weightLabel
              anchors.verticalCenter: parent.verticalCenter
            }
          }
          MouseArea {
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.setProfile(index)
          }
        }
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
