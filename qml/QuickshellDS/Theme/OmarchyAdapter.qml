pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool enabled: true
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (root.home + "/.local/state")
    readonly property string themeDir: root.stateHome + "/omarchy/current/theme"

    property bool colorsLoaded: false
    property bool shellLoaded: false

    function parseFlatToml(raw: string): var {
        const result = ({})
        if (!raw)
            return result
        const lines = raw.split("\n")
        let section = ""
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i].trim()
            if (line.length === 0 || line.charAt(0) === "#")
                continue
            const sec = line.match(/^\[([A-Za-z0-9_-]+)\]\s*(#.*)?$/)
            if (sec) {
                section = sec[1]
                continue
            }
            const strKv = line.match(/^([A-Za-z0-9_-]+)\s*=\s*["']([^"']+)["']\s*(#.*)?$/)
            const numKv = line.match(/^([A-Za-z0-9_-]+)\s*=\s*(-?\d+(?:\.\d+)?)\s*(#.*)?$/)
            const bareKv = line.match(/^([A-Za-z0-9_-]+)\s*=\s*(true|false|[A-Za-z][A-Za-z0-9_-]*)\s*(#.*)?$/)
            const kv = strKv || numKv || bareKv
            if (!kv)
                continue
            const key = section.length > 0 ? (section + "." + kv[1]) : kv[1]
            result[key] = kv[2]
        }
        return result
    }

    function applyColorsToml(raw: string): void {
        if (!root.enabled)
            return
        const map = root.parseFlatToml(raw)
        if (!map.background || !map.foreground) {
            root.fallbackToPalette()
            return
        }
        const bg = map.dark_background || map.darker_background || map.background
        const surface = map.background
        const raised = map.lighter_background || map.background
        const hover = map.selection || map.lighter_background || map.muted || "#222429"
        const active = map.muted || map.selection || "#2c3036"
        const accent = map.accent || map.blue || map.foreground
        const accentHover = map.bright_blue || Qt.lighter(accent, 1.15)
        let mutedColor = Qt.color(map.dark_foreground || "#8e8e93")
        const fgColor = Qt.color(map.foreground)
        const raisedColor = Qt.color(raised)
        for (let step = 0; step < 10 && Palettes.contrastRatio(mutedColor, raisedColor) < 4.6; ++step) {
            mutedColor = Qt.rgba(
                mutedColor.r + (fgColor.r - mutedColor.r) * 0.15,
                mutedColor.g + (fgColor.g - mutedColor.g) * 0.15,
                mutedColor.b + (fgColor.b - mutedColor.b) * 0.15,
                1.0
            )
        }

        Tokens.applyPalette({
            bg: bg,
            surface: surface,
            surfaceRaised: raised,
            surfaceHover: hover,
            surfaceActive: active,
            border: map.muted || "#262626",
            borderStrong: map.active_border_color || accent,
            text: map.foreground,
            textMuted: mutedColor,
            accent: accent,
            accentHover: accentHover,
            red: map.red || "#ff453a",
            green: map.green || "#32d74b",
            yellow: map.yellow || "#ffd60a",
            blue: map.blue || "#0a84ff"
        }, "omarchy", "Omarchy Live", map.mode || "dark")
        root.colorsLoaded = true
    }

    function applyShellToml(raw: string): void {
        if (!root.enabled)
            return
        const map = root.parseFlatToml(raw)
        let loadedAny = false

        if (map["bar.size-horizontal"]) {
            const h = Number(map["bar.size-horizontal"])
            if (isFinite(h) && h > 0) {
                Tokens.barHeightOverride = h
                loadedAny = true
            }
        }
        if (map["bar.background-alpha"]) {
            const a = Number(map["bar.background-alpha"])
            if (isFinite(a) && a >= 0 && a <= 1) {
                Tokens.shellBarAlpha = a
                loadedAny = true
            }
        }
        if (map["spacing.scale"]) {
            const s = Number(map["spacing.scale"])
            if (isFinite(s) && s > 0.5 && s <= 2.5) {
                Tokens.spacingScaleOverride = s
                loadedAny = true
            }
        }
        root.shellLoaded = loadedAny
    }

    function fallbackToPalette(): void {
        root.colorsLoaded = false
        if (Tokens.activePaletteId === "omarchy")
            Tokens.selectPalette("monochrome_dark")
    }

    function refreshHyprlandMetrics(): void {
        if (!root.enabled)
            return
        roundingProc.running = true
        gapsProc.running = true
    }

    readonly property FileView colorsFile: FileView {
        path: root.themeDir + "/colors.toml"
        watchChanges: root.enabled
        printErrors: false
        onLoaded: {
            root.applyColorsToml(text())
            root.refreshHyprlandMetrics()
        }
        onFileChanged: {
            watchChanges = false
            watchChanges = root.enabled
            reload()
        }
        onLoadFailed: root.fallbackToPalette()
    }

    readonly property FileView shellFile: FileView {
        path: root.themeDir + "/shell.toml"
        watchChanges: root.enabled
        printErrors: false
        onLoaded: root.applyShellToml(text())
        onFileChanged: {
            watchChanges = false
            watchChanges = root.enabled
            reload()
        }
        onLoadFailed: root.shellLoaded = false
    }

    readonly property Process roundingProc: Process {
        command: ["hyprctl", "-j", "getoption", "decoration:rounding"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (typeof data.int === "number")
                        Tokens.compositorRounding = Math.max(0, data.int)
                } catch (e) {
                }
            }
        }
    }

    readonly property Process gapsProc: Process {
        command: ["hyprctl", "-j", "getoption", "general:gaps_out"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (typeof data.custom === "string") {
                        const first = parseInt(data.custom.trim().split(/\s+/)[0], 10)
                        if (!isNaN(first))
                            Tokens.compositorGapsOut = Math.max(0, first)
                    } else if (typeof data.int === "number") {
                        Tokens.compositorGapsOut = Math.max(0, data.int)
                    }
                } catch (e) {
                }
            }
        }
    }
}
