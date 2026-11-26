pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Core"
import "../Services"
import "../MenuCore/MenuModel.js" as MenuModel
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

// Menu: streamlined 6-category Command Hub + dmenu bridge.
// Supports both Topbar Morphed and Centered Spotlight presentation via IslandWindow.
WidgetSurface {
  id: root

  preferredWidth: dmenu && MenuData.request.width > 0
    ? Math.max(600, Math.min(Tokens.px(760), MenuData.request.width))
    : 660
  scrollTarget: list
  hint: "type to search · ↑/↓ move · ↵ open · Tab category · Ctrl+P pin · Esc back"

  Accessible.role: Accessible.Pane
  Accessible.name: qsTr("Command menu")

  readonly property bool wantsKeyboard: true
  readonly property bool dmenu: MenuData.request.active === true
  readonly property bool dmenuInput: dmenu && MenuData.request.mode === "input"
  readonly property string dmenuPrompt: dmenu ? String(MenuData.request.prompt || "") : ""
  readonly property bool capturesEscape: dmenu ? query !== "" : (query !== "" || route !== "root")

  property string activeTab: "home"    // "home" | "apps" | "trigger" | "packages" | "setup" | "docs"
  property string pkgSubTab: "install" // "install" | "remove" | "update"
  property string route: "root"
  property string query: ""
  property int sel: 0

  readonly property var mainTabs: [
    { id: "home", label: qsTr("Home") },
    { id: "apps", label: qsTr("Apps") },
    { id: "trigger", label: qsTr("Actions") },
    { id: "packages", label: qsTr("Packages") },
    { id: "setup", label: qsTr("Setup") },
    { id: "docs", label: qsTr("Docs") }
  ]

  readonly property var pkgTabs: [
    { id: "install", label: qsTr("Install") },
    { id: "remove", label: qsTr("Remove") },
    { id: "update", label: qsTr("Update") }
  ]

  readonly property var rows: {
    MenuData.revision
    if (dmenu) return dmenuRows()
    if (query.charAt(0) === "/") {
      var scope = route === "root" ? scopeForTab(activeTab) : route
      return MenuData.searchWithin(scope, qText(), 60)
    }
    if (query !== "") return MenuData.search(query, 60)
    if (route !== "root") return MenuData.childrenOf(route)
    if (activeTab === "home") return homeRows()
    if (activeTab === "packages") return MenuData.childrenOf(pkgSubTab)
    if (activeTab === "docs") return docsRows()
    return MenuData.childrenOf(activeTab)
  }

  function scopeForTab(tab) {
    if (tab === "packages") return pkgSubTab
    if (tab === "docs") return "learn"
    return tab
  }

  function withSection(entry, section) {
    var o = {}
    for (var k in entry) o[k] = entry[k]
    o.section = section
    return o
  }

  function homeRows() {
    var out = []
    var pinned = MenuData.pinnedRows()
    for (var p = 0; p < pinned.length; p++) out.push(withSection(pinned[p], "Pinned"))
    var recent = MenuData.recentRows()
    for (var i = 0; i < recent.length; i++) {
      if (pinned.indexOf(recent[i]) < 0) out.push(withSection(recent[i], "Recent"))
    }
    if (out.length === 0) {
      var apps = MenuData.childrenOf("apps").slice(0, 8)
      for (var a = 0; a < apps.length; a++) out.push(withSection(apps[a], "Quick Apps"))
    }
    return out
  }

  function docsRows() {
    var out = MenuData.childrenOf("learn").slice()
    var about = MenuData.item("about")
    if (about && MenuData.visible(about)) out.push(withSection(about, "System"))
    return out
  }

  function qText() { return query.charAt(0) === "/" ? query.slice(1).trim() : query.trim() }

  function hexOf(c) {
    function h(v) { var n = Math.round(v * 255).toString(16); return n.length < 2 ? "0" + n : n }
    return "#" + h(c.r) + h(c.g) + h(c.b)
  }
  function esc(t) { return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
  function markedLabel(label, q) {
    var s = String(label || ""), needle = String(q || "").toLowerCase().replace(/\s+/g, "")
    if (needle === "") return esc(s)
    var lower = s.toLowerCase(), out = "", j = 0
    for (var i = 0; i < s.length; i++) {
      var ch = s.charAt(i)
      if (j < needle.length && lower.charAt(i) === needle.charAt(j)) {
        out += "<b><font color=\"" + hexOf(Tokens.color.accent) + "\">" + esc(ch) + "</font></b>"
        j++
      } else {
        out += esc(ch)
      }
    }
    return out
  }

  function dmenuRows() {
    if (dmenuInput) return []
    var out = []
    var q = query.trim().toLowerCase()
    var options = MenuData.request.options || []
    for (var i = 0; i < options.length; i++) {
      var parts = String(options[i] || "").split("\t")
      var icon = parts.length > 1 ? parts.shift() : ""
      var rawLabel = parts.shift() || ""
      var label = rawLabel
      var shortcut = ""
      if (icon === "") {
        var arrow = rawLabel.indexOf(" → ")
        if (arrow > 0) {
          shortcut = rawLabel.slice(0, arrow).trim()
          label = rawLabel.slice(arrow + 3).trim()
        }
      }
      var detail = parts.join("\t")
      if (q && label.toLowerCase().indexOf(q) < 0 && shortcut.toLowerCase().indexOf(q) < 0 && detail.toLowerCase().indexOf(q) < 0) continue
      out.push({
        id: "dmenu." + i,
        kind: "dmenu",
        label: label,
        shortcut: shortcut,
        icon: icon,
        description: detail,
        answer: detail ? rawLabel + "\t" + detail : rawLabel,
        section: ""
      })
    }
    return out
  }

  function headerIcon() {
    if (query !== "" || dmenu) return "search"
    if (route !== "root") return svgForEntry({ id: route })
    if (activeTab === "apps") return "layout-grid"
    if (activeTab === "trigger") return "zap"
    if (activeTab === "packages") return "package"
    if (activeTab === "setup") return "wrench"
    if (activeTab === "docs") return "book-open"
    return "search"
  }

  function svgForEntry(e) {
    var id = String((e && e.id) || "")
    if (id === "apps" || id.indexOf("apps.") === 0) return "layout-grid"
    if (id.indexOf("install") === 0) return "download"
    if (id.indexOf("remove") === 0) return "trash-2"
    if (id.indexOf("update") === 0) return "refresh-cw"
    if (id.indexOf("trigger.capture") === 0) return "camera"
    if (id.indexOf("trigger.clipboard") === 0) return "clipboard"
    if (id.indexOf("trigger.share") === 0) return "external-link"
    if (id.indexOf("trigger.hardware") === 0) return "cpu"
    if (id.indexOf("trigger.toggle") === 0) return "sliders-horizontal"
    if (id.indexOf("trigger") === 0) return "zap"
    if (id.indexOf("setup.monitors") === 0) return "monitor"
    if (id.indexOf("setup.network") === 0) return "wifi"
    if (id.indexOf("setup.security") === 0) return "shield"
    if (id.indexOf("setup.keybindings") === 0 || id.indexOf("learn.keybindings") === 0) return "key"
    if (id.indexOf("setup.power") === 0) return "power"
    if (id.indexOf("setup.audio") === 0) return "volume"
    if (id.indexOf("setup.bluetooth") === 0) return "bluetooth"
    if (id.indexOf("setup") === 0) return "wrench"
    if (id.indexOf("learn") === 0) return "book-open"
    if (id === "about") return "info"
    if (id.indexOf("appearance") === 0) return "palette"
    if (id.indexOf("system") === 0) return "settings"
    return "sparkles"
  }

  function tabForTopId(topId) {
    if (topId === "apps" || topId === "trigger" || topId === "setup") return topId
    if (topId === "install" || topId === "remove" || topId === "update") {
      pkgSubTab = topId
      return "packages"
    }
    if (topId === "learn" || topId === "about") return "docs"
    return "home"
  }

  function applyOpen() {
    query = ""; sel = 0
    root.forceActiveFocus()
    if (dmenu) { route = "root"; return }
    route = MenuData.pendingRoute || "root"
    if (route === "root") {
      activeTab = tabForTopId(MenuData.lastRail || "home")
    } else {
      activeTab = tabForTopId(MenuModel.topLevelFor(MenuData.items, route))
    }
  }

  Connections { target: MenuData; function onOpenSerialChanged() { root.applyOpen() } }
  Component.onCompleted: { MenuData.refresh(); applyOpen() }
  Component.onDestruction: {
    MenuData.cancelRequest()
    Cmd.run(["omarchy-shell", "-q", "menu", "closed"])
  }

  readonly property var debugState: ({ route: route, activeTab: activeTab, query: query, sel: sel, rows: rows.length })

  function navigable(e) { return !!e && (e.kind === "menu" || e.kind === "link" || e.provider !== "") }
  function enter(id) { route = id; sel = 0; query = ""; listFade.restart() }
  function up() {
    var cur = MenuData.item(route)
    if (!cur) { route = "root"; sel = 0; listFade.restart(); return }
    route = cur.parent || "root"
    if (route === "root") activeTab = tabForTopId(cur.id)
    sel = 0
    listFade.restart()
  }

  function stepMainTab(delta) {
    var idx = mainTabs.findIndex(function (t) { return t.id === activeTab })
    var next = (Math.max(0, idx) + delta + mainTabs.length) % mainTabs.length
    activeTab = mainTabs[next].id
    route = "root"
    query = ""
    sel = 0
    MenuData.setLastRail(activeTab)
    listFade.restart()
  }

  NumberAnimation {
    id: listFade
    target: list
    property: "opacity"
    from: 0.25
    to: 1.0
    duration: (Tokens.reducedMotion || Tokens.gameMode) ? 0 : Math.round(120 * Tokens.motionScale)
    easing.type: Easing.OutCubic
  }

  function accept(e) {
    if (dmenuInput) { MenuData.finishRequest(query); IslandState.closeWidget(); return }
    if (!e) return
    MenuData.finishRequest(e.answer !== undefined ? e.answer : e.label)
    IslandState.closeWidget()
  }

  function open(e) {
    if (!e) return
    if (dmenu) { accept(e); return }
    if (navigable(e)) {
      if (e.kind === "link" && e.target) enter(e.target)
      else enter(e.id)
      return
    }
    IslandState.closeWidget()
    MenuData.activate(e)
  }

  function pinnedOn(e) { return !!e && MenuData.pins.indexOf(e.id) >= 0 }

  Keys.onPressed: function (e) {
    var n = rows.length
    if (dmenu) {
      if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, Math.max(0, n - 1)); e.accepted = true }
      else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
      else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
        if (dmenuInput) accept(null); else if (rows[sel]) accept(rows[sel])
        e.accepted = true
      } else if (e.key === Qt.Key_Backspace) {
        if (query !== "") { query = query.slice(0, -1); sel = 0 }
        e.accepted = true
      } else if (e.key === Qt.Key_Escape) {
        if (query !== "") { query = ""; sel = 0; e.accepted = true }
      } else if (e.text.length === 1 && e.text >= " ") {
        query += e.text; sel = 0; e.accepted = true
      }
      return
    }

    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, Math.max(0, n - 1)); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (rows[sel]) open(rows[sel]); e.accepted = true }
    else if (e.key === Qt.Key_Right) { if (rows[sel] && navigable(rows[sel])) open(rows[sel]); e.accepted = true }
    else if (e.key === Qt.Key_Tab) { stepMainTab(1); e.accepted = true }
    else if (e.key === Qt.Key_Backtab) { stepMainTab(-1); e.accepted = true }
    else if (e.key === Qt.Key_P && (e.modifiers & Qt.ControlModifier)) {
      var pr = rows[sel]
      if (pr && pr.kind !== "dmenu") MenuData.togglePin(pr.id)
      e.accepted = true
    } else if (e.key === Qt.Key_Delete) {
      var r = rows[sel]
      if (r && r.section === "Recent" && query === "") {
        MenuData.forgetRecent(r.id)
        sel = Math.max(0, Math.min(sel, rows.length - 2))
      }
      e.accepted = true
    } else if (e.key === Qt.Key_Left) {
      if (route !== "root" && query === "") up()
      else stepMainTab(-1)
      e.accepted = true
    } else if (e.key === Qt.Key_Backspace) {
      if (query !== "") { query = query.slice(0, -1); sel = 0 }
      else if (route !== "root") up()
      e.accepted = true
    } else if (e.key === Qt.Key_Escape) {
      if (query !== "") { query = ""; sel = 0; e.accepted = true }
      else if (route !== "root") { up(); e.accepted = true }
    } else if (e.text.length === 1 && e.text >= " ") {
      query += e.text; sel = 0; e.accepted = true
    }
  }

  // ---- Borderless Hero Search Header ----
  Column {
    width: parent.width
    spacing: 0

    RowLayout {
      width: parent.width
      height: Tokens.px(46)
      spacing: Tokens.space.sm

      Button {
        visible: !root.dmenu && root.route !== "root" && root.query === ""
        icon: "chevron-left"
        variant: "ghost"
        size: "sm"
        shape: "circle"
        accessibleLabel: qsTr("Back")
        onClicked: root.up()
      }

      Icon {
        name: root.headerIcon()
        size: Tokens.size.iconMd
        tone: root.query !== "" ? "accent" : "muted"
      }

      TextLabel {
        Layout.fillWidth: true
        font.pixelSize: Tokens.px(15)
        tone: root.query === "" ? "muted" : "primary"
        font.weight: root.query === "" ? Font.Normal : Font.Medium
        text: root.query !== "" ? root.query
            : (root.dmenu && root.dmenuPrompt !== "" ? root.dmenuPrompt
            : qsTr("Search apps, commands, or / to filter…"))
      }

      Badge {
        visible: !root.dmenu && root.route !== "root"
        text: (MenuData.item(root.route) || {}).label || ""
        tone: "accent"
      }

      Badge {
        visible: !root.dmenuInput && root.query !== ""
        text: root.rows.length + (root.rows.length === 1 ? " item" : " items")
        tone: "neutral"
      }
    }

    Rectangle {
      width: parent.width
      height: Tokens.hairlineWidth
      color: Tokens.color.hairline
    }
  }

  // ---- Airy Category Strip ----
  ColumnLayout {
    visible: !root.dmenu
    width: parent.width
    spacing: Tokens.space.xs

    TabStrip {
      Layout.fillWidth: true
      tabs: root.mainTabs
      current: root.activeTab
      onPicked: function (id) {
        root.activeTab = id
        root.route = "root"
        root.query = ""
        root.sel = 0
        MenuData.setLastRail(id)
      }
    }

    SegmentedControl {
      visible: root.activeTab === "packages" && root.route === "root" && root.query === ""
      Layout.alignment: Qt.AlignLeft
      options: root.pkgTabs
      current: root.pkgSubTab
      onSelected: function (id) { root.pkgSubTab = id; root.sel = 0 }
    }
  }

  // ---- Content-Fitted Borderless Results List ----
  Item {
    width: parent.width
    height: list.count > 0
      ? Math.min(6 * (Tokens.px(52) + Tokens.space.xs) - Tokens.space.xs, Math.max(Tokens.px(96), list.contentHeight))
      : Tokens.px(120)

    ListView {
      id: list
      anchors.fill: parent
      clip: true
      spacing: Tokens.space.xs
      model: root.rows
      currentIndex: root.sel
      boundsBehavior: Flickable.StopAtBounds
      onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

      section.property: "section"
      section.criteria: ViewSection.FullString
      section.delegate: Item {
        id: secItem
        required property string section
        width: list.width
        height: section === "" ? 0 : Tokens.px(24)
        TextLabel {
          visible: secItem.section !== ""
          x: Tokens.space.md
          anchors.verticalCenter: parent.verticalCenter
          role: "caption"
          tone: "muted"
          font.letterSpacing: 0.9
          text: secItem.section.toUpperCase()
        }
      }

      delegate: Surface {
        id: rowCard
        required property var modelData
        required property int index

        readonly property bool isSelected: root.sel === rowCard.index
        width: list.width
        height: Tokens.px(52)
        role: "bare"
        radius: Tokens.radius.md
        hovered: rowHover.hovered
        showBorder: false
        color: (rowCard.isSelected || rowHover.hovered)
          ? Tokens.veilHoverOf(Tokens.surfaceStyle)
          : "transparent"
        horizontalPadding: Tokens.space.lg
        verticalPadding: Tokens.space.sm

        Accessible.role: Accessible.ListItem
        Accessible.name: rowCard.modelData.label || ""

        FocusRing { active: rowCard.isSelected; ringRadius: Tokens.radius.md }

        Rectangle {
          anchors.left: parent.left
          anchors.leftMargin: Tokens.space.xs - rowCard.horizontalPadding
          anchors.verticalCenter: parent.verticalCenter
          width: Tokens.px(3)
          height: Tokens.px(22)
          radius: Tokens.radius.pill
          color: Tokens.color.accent
          visible: rowCard.isSelected
        }

        HoverHandler {
          id: rowHover
          cursorShape: Qt.PointingHandCursor
          onHoveredChanged: if (hovered) root.sel = rowCard.index
        }

        TapHandler {
          onTapped: {
            root.sel = rowCard.index
            root.open(rowCard.modelData)
          }
        }

        RowLayout {
          anchors.fill: parent
          spacing: Tokens.space.md

          // Leading Icon (28 px crisp app icon or vector SVG)
          Item {
            Layout.preferredWidth: Tokens.px(28)
            Layout.preferredHeight: Tokens.px(28)
            visible: rowCard.modelData.kind !== "dmenu" || (rowCard.modelData.icon || "") !== ""

            Image {
              anchors.fill: parent
              visible: rowCard.modelData.kind === "app" && (rowCard.modelData.icon || "") !== ""
              source: visible ? (Quickshell.iconPath(rowCard.modelData.icon, true) || "") : ""
              sourceSize: Qt.size(Math.ceil(28 * Tokens.dpr), Math.ceil(28 * Tokens.dpr))
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              smooth: true
            }

            Icon {
              anchors.centerIn: parent
              visible: rowCard.modelData.kind !== "app"
              name: root.svgForEntry(rowCard.modelData)
              size: Tokens.size.iconMd
              tone: rowCard.isSelected ? "accent" : "muted"
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.space.xxs

            TextLabel {
              Layout.fillWidth: true
              role: "body"
              font.weight: rowCard.isSelected ? Font.Medium : Font.Normal
              textFormat: root.qText() !== "" ? Text.StyledText : Text.PlainText
              text: root.qText() !== "" ? root.markedLabel(rowCard.modelData.label, root.qText()) : (rowCard.modelData.label || "")
            }

            TextLabel {
              Layout.fillWidth: true
              readonly property string desc: String(rowCard.modelData.description || "").trim()
              readonly property string lbl: String(rowCard.modelData.label || "").trim()
              visible: desc !== "" && desc.toLowerCase() !== lbl.toLowerCase()
              role: "sm"
              tone: "muted"
              textFormat: Text.PlainText
              text: desc
            }
          }

          Keycap {
            visible: (rowCard.modelData.shortcut || MenuData.shortcutFor(rowCard.modelData) || "") !== ""
            text: rowCard.modelData.shortcut || MenuData.shortcutFor(rowCard.modelData) || ""
            size: "sm"
          }

          Icon {
            visible: root.pinnedOn(rowCard.modelData)
            name: "star"
            size: Tokens.size.iconXs
            tone: "accent"
          }

          Icon {
            visible: rowCard.modelData.checked === true
            name: "check"
            size: Tokens.size.iconSm
            tone: "success"
          }

          Icon {
            visible: root.navigable(rowCard.modelData)
            name: "chevron-right"
            size: Tokens.size.iconSm
            tone: "muted"
          }
        }
      }
    }

    EmptyState {
      anchors.centerIn: parent
      visible: list.count === 0
      icon: "search"
      title: root.query !== "" ? qsTr("No matching results") : qsTr("Nothing here yet")
      description: root.query !== "" ? qsTr("Try a different search term") : qsTr("Pin actions with Ctrl+P")
    }
  }
}
