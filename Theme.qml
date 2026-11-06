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

  // Blend two colours: t = 0 gives a, t = 1 gives b.
  function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t) }
  // Nudge `fg` toward `toward` just far enough to reach `min` contrast on EVERY
  // background in `bgs`. Keeps a muted colour muted (instead of snapping to pure
  // white/black) whenever that is possible; flips only as a last resort.
  function lift(fg, bgs, toward, min) {
    function ok(c) { for (var i = 0; i < bgs.length; i++) if (contrast(c, bgs[i]) < min) return false; return true }
    for (var t = 0; t <= 1.001; t += 0.05) { var c = mix(fg, toward, t); if (ok(c)) return c }
    var light = Qt.rgba(1, 1, 1, 1), dark = Qt.rgba(0, 0, 0, 1)
    return ok(light) ? light : dark
  }

  property bool dark: luminance(Qt.color(pick("background"))) < 0.4

  // ================= layout tokens (one place for every size) =================
  // Spacing scale.
  readonly property int s4: 4
  readonly property int s8: 8
  readonly property int s12: 12
  readonly property int s16: 16
  readonly property int s20: 20
  // Panels: one padding on all four sides. (The earlier panels mixed 14 to 24.)
  readonly property int panelPadding: 16
  readonly property int rowGap: 4          // between rows in a list
  readonly property int sectionGap: 12     // between sections of a panel
  readonly property int rowHeight: 44
  readonly property int sliderHeight: 44
  readonly property int tileHeight: 56
  readonly property int tileRadius: 18
  readonly property int pillRadius: IslandState.cornerRadius + 4   // matches the Compass menu
  readonly property int panelMaxHeight: 420    // the fixed layer window is sized for this
  readonly property int panelMinHeight: 48
  readonly property int panelMaxWidth: 720
  readonly property int iconSm: 16
  readonly property int iconMd: 20
  readonly property int iconLg: 24

  // ---- Semantic roles. Each has a Behavior, so a theme switch cross-fades
  // over 250ms instead of snapping. ----
  property color background: Qt.color(pick("background"))
  property color surface: Qt.color(pick("lighter_background"))
  property color surfaceRaised: Qt.color(pick("selection"))
  property color outline: Qt.color(pick("muted"))
  property color text: readable(Qt.color(pick("foreground")), surface, 4.5)
  // Secondary text must stay legible (>= 4.5:1) on the pill AND on tiles/rows.
  property color textMuted: lift(Qt.color(pick("dark_foreground")), [surface, surfaceRaised, background], Qt.color(pick("foreground")), 4.5)
  property color accent: Qt.color(pick("accent"))
  property color accentText: readable(background, accent, 4.5)
  // Secondary text ON an accent fill (tile subtitles, badges): slightly softer than
  // accentText but still >= 4.5:1 against the accent.
  // Accent/status colours as TEXT, ICONS or LINES: nudged toward the text colour until they reach
  // 4.5:1 on the pill, tiles and raised rows. Use the plain accent/success/warning/danger only for
  // FILLS (with accentText / textOnWarning / textOnDanger on top), never for text.
  property color accentInk: lift(accent, [surface, surfaceRaised, background], Qt.color(pick("foreground")), 4.5)
  property color successInk: lift(success, [surface, surfaceRaised, background], Qt.color(pick("foreground")), 4.5)
  property color warningInk: lift(warning, [surface, surfaceRaised, background], Qt.color(pick("foreground")), 4.5)
  property color dangerInk: lift(danger, [surface, surfaceRaised, background], Qt.color(pick("foreground")), 4.5)
  property color textOnWarning: readable(background, warning, 4.5)
  property color textOnDanger: readable(background, danger, 4.5)
  property color textOnAccentMuted: lift(mix(accentText, accent, 0.25), [accent], accentText, 4.5)
  // Small label colour on a normal (inactive) tile, e.g. the number badge.
  property color badgeText: lift(mix(text, surface, 0.4), [surface, surfaceRaised], text, 4.5)
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
  Behavior on accentInk { ColorAnimation { duration: 250 } }
  Behavior on successInk { ColorAnimation { duration: 250 } }
  Behavior on warningInk { ColorAnimation { duration: 250 } }
  Behavior on dangerInk { ColorAnimation { duration: 250 } }
  Behavior on textOnAccentMuted { ColorAnimation { duration: 250 } }
  Behavior on badgeText { ColorAnimation { duration: 250 } }
  Behavior on success { ColorAnimation { duration: 250 } }
  Behavior on warning { ColorAnimation { duration: 250 } }
  Behavior on danger { ColorAnimation { duration: 250 } }

  // Contrast audit: every text/background pair the UI uses, with its ratio.
  // `omarchy-shell island debug contrast` prints this; anything under 4.5 is flagged.
  function audit() {
    var pairs = [
      ["text/background", text, background], ["text/surface", text, surface], ["text/surfaceRaised", text, surfaceRaised],
      ["textMuted/background", textMuted, background], ["textMuted/surface", textMuted, surface], ["textMuted/surfaceRaised", textMuted, surfaceRaised],
      ["badgeText/surface", badgeText, surface], ["badgeText/surfaceRaised", badgeText, surfaceRaised],
      ["accentText/accent", accentText, accent], ["textOnAccentMuted/accent", textOnAccentMuted, accent],
      ["accentInk/surface", accentInk, surface], ["accentInk/background", accentInk, background], ["accentInk/surfaceRaised", accentInk, surfaceRaised],
      ["successInk/surface", successInk, surface], ["warningInk/surface", warningInk, surface], ["dangerInk/surface", dangerInk, surface],
      ["successInk/background", successInk, background], ["warningInk/background", warningInk, background], ["dangerInk/background", dangerInk, background],
      ["textOnWarning/warning", textOnWarning, warning], ["textOnDanger/danger", textOnDanger, danger]
    ]
    return pairs.map(function (p) { var r = contrast(p[1], p[2]); return { pair: p[0], ratio: +r.toFixed(2), pass: r >= 4.5, fg: String(p[1]), bg: String(p[2]) } })
  }

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
