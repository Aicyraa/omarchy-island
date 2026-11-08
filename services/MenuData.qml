pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../menu-core/MenuModel.js" as MenuModel
import "../menu-core/MenuHidden.js" as MenuHidden

// MenuData: Omarchy's menu tree as the island's menu widget shows it.
//   * The tree: the stock jsonc, overridden by the user's extension, minus the sections the island replaces
//     (menu-core/MenuHidden.js). Read from disk on load and whenever either file changes.
//   * Installed apps: every desktop entry, as `apps.<id>` rows (kind "app"), launched through DesktopEntries.
//   * Guards: one read-only bash batch for every `when:`, `checked:` and `disabled:`; it runs when the tree loads and
//     each time the menu opens (Omarchy's own checks, so an installed app's Install row is hidden).
// Recents and frecency are not part of this milestone.
Singleton {
  id: root
  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  readonly property string userPath: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"

  property string stockText: ""
  property string userText: ""
  property var items: ({})
  property var itemOrder: []
  property var whenResults: ({})
  property var checkedResults: ({})
  property var disabledResults: ({})
  property int revision: 0
  readonly property bool guardsRunning: guards.running

  FileView { path: root.omarchyPath + "/default/omarchy/omarchy-menu.jsonc"; printErrors: false; watchChanges: true
    onFileChanged: reload()
    onLoaded: root.stockText = text()
    onLoadFailed: root.stockText = "" }
  FileView { path: root.userPath; printErrors: false; watchChanges: true
    onFileChanged: reload()
    onLoaded: root.userText = text()
    onLoadFailed: root.userText = "" }

  onStockTextChanged: rebuild()
  onUserTextChanged: rebuild()

  // Installed software changes the desktop entries; rebuild the app rows when they do (and on each open).
  readonly property int desktopCount: DesktopEntries.applications.values.length
  onDesktopCountChanged: rebuild()

  function rebuild() {
    var merged = MenuModel.mergeMenuSources(MenuModel.parseMenuJsonc(stockText), MenuModel.parseMenuJsonc(userText), MenuHidden.hide)
    var next = withApps(merged.items, merged.itemOrder)
    items = next.items
    itemOrder = next.itemOrder
    revision += 1
    refreshGuards()
  }

  // Installed apps are rebuilt from DesktopEntries each time (they change when software is installed or removed).
  function withApps(baseItems, baseOrder) {
    var out = ({})
    for (var k in baseItems) if (baseItems[k].kind !== "app") out[k] = baseItems[k]
    var order = []
    for (var i = 0; i < baseOrder.length; i++) if (out[baseOrder[i]]) order.push(baseOrder[i])
    var entries = DesktopEntries.applications.values
    var rows = []
    for (var j = 0; j < entries.length; j++) {
      var e = entries[j]
      if (!e || e.noDisplay || !e.name) continue
      rows.push(e)
    }
    rows.sort(function (a, b) { return String(a.name).localeCompare(String(b.name)) })
    for (var r = 0; r < rows.length; r++) {
      var id = "apps." + MenuModel.slugify(rows[r].id || rows[r].name)
      if (out[id]) id += "-" + r
      out[id] = { id: id, parent: "apps", kind: "app", icon: rows[r].icon || "", iconFont: "", label: rows[r].name,
                  title: "", target: "", description: rows[r].genericName || "", action: "", provider: "", aliases: [],
                  when: "", checked: "", disabled: "", order: r, desktop: rows[r] }
      order.push(id)
    }
    return { items: out, itemOrder: order }
  }

  // ---- guards: one read-only batch, results keyed by id ----
  function refreshGuards() {
    if (guards.running) { guardsPending = true; return }
    guardsPending = false
    var script = MenuModel.guardScript(items)
    if (!script) { whenResults = ({}); checkedResults = ({}); disabledResults = ({}); return }
    guards.command = ["bash", "-lc", script]
    guards.running = true
  }
  property bool guardsPending: false

  Process {
    id: guards
    stdout: StdioCollector {
      onStreamFinished: {
        var nextWhen = ({}), nextChecked = ({}), nextDisabled = ({})
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim()
          if (!line) continue
          var colon = line.lastIndexOf(":")
          if (colon < 0) continue
          var value = line.substring(colon + 1) === "1"
          var rest = line.substring(0, colon)
          var tagAt = rest.lastIndexOf(":")
          if (tagAt < 0) continue
          var id = rest.substring(0, tagAt), tag = rest.substring(tagAt + 1)
          if (tag === "w") nextWhen[id] = value
          else if (tag === "c") nextChecked[id] = value
          else if (tag === "d") nextDisabled[id] = value
        }
        root.whenResults = nextWhen
        root.checkedResults = nextChecked
        root.disabledResults = nextDisabled
        root.revision += 1
      }
    }
    onExited: function (code) { if (root.guardsPending) Qt.callLater(function () { root.refreshGuards() }) }
  }

  // Re-check everything (called when the menu opens). Cheap enough: one batch of read-only checks.
  function refresh() { rebuild() }
  Component.onCompleted: rebuild()

  // ---- queries used by the widget ----
  function visible(entry) {
    return MenuModel.isVisible(items, itemOrder, whenResults, entry, 0, disabledResults)
  }
  function childrenOf(id) {
    var out = []
    for (var i = 0; i < itemOrder.length; i++) {
      var e = items[itemOrder[i]]
      if (e && e.parent === id && e.id !== id && visible(e)) out.push(e)
    }
    return out
  }
  function search(query, limit) {
    var hits = []
    for (var i = 0; i < itemOrder.length; i++) {
      var e = items[itemOrder[i]]
      if (!e || e.id === "root") continue
      if (!MenuModel.matchesQuery(e, query, visible(e))) continue
      hits.push({ entry: e, score: MenuModel.searchScore(items, e, query) })
    }
    hits.sort(function (a, b) { return a.score - b.score })
    return hits.slice(0, limit || 60).map(function (h) { return h.entry })
  }
  function item(id) { return items[id] || null }

  // Run a row: apps launch through DesktopEntries; actions run through a login shell (the same as the stock menu).
  function activate(entry) {
    if (!entry) return
    if (entry.kind === "app") { if (entry.desktop) entry.desktop.execute(); return }
    if (entry.kind === "action" && entry.action) Cmd.run(["bash", "-lc", entry.action])
  }
}
