pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Theme: the ONLY place colours come from. Everything else in the plugin reads
// semantic roles (Theme.surface, Theme.text, ...) and never a hex literal.
//
// Source of truth: ~/.local/state/omarchy/current/theme/colors.toml, the
// palette file every Omarchy theme ships (Omarchy's own Commons/Color.qml reads
// the same file). Roles are derived from it, then passed through a contrast
// guard so text stays readable on any theme, light or dark.
Singleton {
  id: root

  // ISLAND_THEME_DIR lets tests point at a fake "current" dir without touching the
  // user's real theme. It is unset in normal use.
  readonly property string themeDir: Quickshell.env("ISLAND_THEME_DIR") || (Quickshell.env("HOME") + "/.local/state/omarchy/current")

  // ---- Fallback block: the only hex literals in the plugin. Used until the
  // palette file loads, or if a key is missing from it. ----
  readonly property var fallback: ({
    background: "#101315", lighter_background: "#1c2124", selection: "#2b3237",
    muted: "#707880", foreground: "#cacccc", dark_foreground: "#8a9096",
    accent: "#cacccc", green: "#7fbf7f", yellow: "#d9b95b", red: "#d46a6a"
  })

  // Parsed palette. We REASSIGN the whole object on every reload instead of
  // mutating it: QML only notices a change to a `var` property when the
  // property itself is assigned, so mutating in place would not recolour.
  property var palette: ({})

  function pick(key) {
    var v = palette[key]
    return (typeof v === "string" && v.length > 0) ? v : fallback[key]
  }

  // Minimal TOML reader: we only need top-level `key = "#rrggbb"` lines.
  function parse(text) {
    var out = {}
    var lines = String(text).split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = /^\s*([A-Za-z_]+)\s*=\s*"([^"]*)"/.exec(lines[i])
      if (m) out[m[1]] = m[2]
    }
    return out
  }

  // ---- WCAG contrast helpers ----
  function lin(c) { return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4) }
  function luminance(c) { return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b) }
  function contrast(a, b) {
    var la = luminance(a), lb = luminance(b)
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
  }
  // Return fg if it reads on bg, otherwise flip to white or black, whichever
  // contrasts more.
  function readable(fg, bg, min) {
    if (contrast(fg, bg) >= min) return fg
    var light = Qt.rgba(1, 1, 1, 1), dark = Qt.rgba(0, 0, 0, 1)
    return contrast(light, bg) >= contrast(dark, bg) ? light : dark
  }

  property bool dark: luminance(Qt.color(pick("background"))) < 0.4

  // ---- Semantic roles. Each has a Behavior, so a theme switch cross-fades
  // over 250ms instead of snapping. ----
  property color background: Qt.color(pick("background"))
  property color surface: Qt.color(pick("lighter_background"))
  property color surfaceRaised: Qt.color(pick("selection"))
  property color outline: Qt.color(pick("muted"))
  property color text: readable(Qt.color(pick("foreground")), surface, 4.5)
  property color textMuted: readable(Qt.color(pick("dark_foreground")), surface, 3.0)
  property color accent: Qt.color(pick("accent"))
  property color accentText: readable(background, accent, 4.5)
  property color success: Qt.color(pick("green"))
  property color warning: Qt.color(pick("yellow"))
  property color danger: Qt.color(pick("red"))
  // The pill itself: the theme background, slightly see-through for blur.
  property color pill: Qt.rgba(background.r, background.g, background.b, 0.94)

  Behavior on background { ColorAnimation { duration: 250 } }
  Behavior on surface { ColorAnimation { duration: 250 } }
  Behavior on surfaceRaised { ColorAnimation { duration: 250 } }
  Behavior on outline { ColorAnimation { duration: 250 } }
  Behavior on text { ColorAnimation { duration: 250 } }
  Behavior on textMuted { ColorAnimation { duration: 250 } }
  Behavior on accent { ColorAnimation { duration: 250 } }
  Behavior on accentText { ColorAnimation { duration: 250 } }
  Behavior on success { ColorAnimation { duration: 250 } }
  Behavior on warning { ColorAnimation { duration: 250 } }
  Behavior on danger { ColorAnimation { duration: 250 } }

  // The palette file may be replaced (new inode) rather than edited on a theme
  // switch, which a plain file watch can miss. So we also watch the generation
  // counter omarchy-theme-set bumps, and reload the palette when either moves.
  FileView {
    id: paletteFile
    path: root.themeDir + "/theme/colors.toml"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.palette = root.parse(text())
  }
  FileView {
    path: root.themeDir + "/theme.generation"
    watchChanges: true
    onFileChanged: paletteFile.reload()
  }
}
