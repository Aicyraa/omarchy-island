pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick

QtObject {
    id: root

    // ── RUNTIME CONFIGURATION ───────────────────────────────────────────────

    property string surfaceStyle: "classic" // "classic" | "glass" | "liquid"
    property bool followCompositorRadius: false
    property int compositorRounding: 0
    property int compositorGapsOut: 10

    property real userScale: 1.0
    property real spacingScaleOverride: 1.0
    property real viewportHeight: 1080
    property bool autoViewportScale: false
    property real dpr: 1.0
    property real barHeightOverride: 0
    property real shellBarAlpha: -1

    property real motionScale: 1.0
    property bool reducedMotion: false
    property bool gameMode: false
    property bool shadowsEnabled: true

    property string activePaletteId: "omarchy"
    property string activePaletteName: "Omarchy Live"
    property string activeMode: "dark"
    readonly property bool isLight: root.activeMode === "light"

    property bool keyboardNavigation: false
    property string density: "comfortable" // "compact" | "comfortable" | "spacious"
    readonly property real densityFactor: root.density === "compact"
        ? 0.86 : (root.density === "spacious" ? 1.15 : 1.0)

    // ── SCALING & GEOMETRY HELPERS ──────────────────────────────────────────

    readonly property real effectiveScale: root.userScale * root.spacingScaleOverride * (root.autoViewportScale
        ? Math.max(0.85, Math.min(1.35, (root.viewportHeight / 80) / 13.5))
        : 1.0)

    function px(value: real): real {
        const scaled = value * root.effectiveScale
        return root.dpr > 0 ? Math.round(scaled * root.dpr) / root.dpr : Math.round(scaled)
    }

    function innerRadius(outerRadius: real, padding: real): real {
        return outerRadius <= 0 ? 0 : Math.max(0, outerRadius - padding)
    }

    readonly property real hairlineWidth: root.dpr > 0
        ? Math.max(1 / root.dpr, Math.round(root.dpr) / root.dpr)
        : 1

    // ── MATERIAL HELPERS ────────────────────────────────────────────────────

    function isTranslucent(style: string): bool {
        return style === "glass" || style === "liquid"
    }

    function isDirectionalLit(style: string): bool {
        return style === "liquid"
    }

    function groundOf(style: string): color {
        if (style === "liquid")
            return root.isLight ? root.color.liquidGroundLight : root.color.liquidGround
        if (style === "glass")
            return root.isLight ? root.color.glassGroundLight : root.color.glassGround
        return root.isLight ? root.color.bg : root.color.islandGround
    }

    function veilOf(style: string): color {
        if (style === "liquid")
            return root.isLight ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.07)
        if (style === "glass")
            return root.isLight ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.08)
        return root.color.surface
    }

    function veilHoverOf(style: string): color {
        if (style === "liquid")
            return root.isLight ? Qt.rgba(1, 1, 1, 0.78) : Qt.rgba(1, 1, 1, 0.13)
        if (style === "glass")
            return root.isLight ? Qt.rgba(1, 1, 1, 0.68) : Qt.rgba(1, 1, 1, 0.14)
        return root.color.surfaceHover
    }

    function veilBorderOf(style: string): color {
        if (style === "liquid")
            return root.isLight ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.18)
        if (style === "glass")
            return root.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.12)
        return root.color.border
    }

    function rimOf(style: string): color {
        if (style === "liquid")
            return root.isLight ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.08)
        if (style === "glass")
            return root.isLight ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.20)
        return root.color.border
    }

    function edgeStrengthOf(style: string): real {
        return style === "liquid" ? 0.72 : 0.12
    }

    function sheenOf(style: string): color {
        return style === "liquid" ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.10)
    }

    // ── TYPED TOKEN GROUPS ──────────────────────────────────────────────────

    component ColorTokens: QtObject {
        property color bg: "#0b0c0d"
        property color surface: "#141414"
        property color surfaceRaised: "#1a1b1f"
        property color surfaceHover: "#222429"
        property color surfaceActive: "#2c3036"

        property color border: "#262626"
        property color borderStrong: "#3a3e44"

        property color text: "#ffffff"
        property color paletteMuted: "#8e8e93"
        readonly property color textSecondary: Qt.rgba(text.r, text.g, text.b, 0.78)
        readonly property color textMuted: root.isDirectionalLit(root.surfaceStyle)
            ? Qt.tint(paletteMuted, Qt.alpha(text, 0.45))
            : paletteMuted
        readonly property color textDisabled: Qt.rgba(text.r, text.g, text.b, 0.40)

        property color accent: "#0a84ff"
        property color accentHover: "#409cff"
        readonly property color accentMuted: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
        readonly property color onAccent: Palettes.contrastInk(accent, "#0b0c0d", "#ffffff")

        property color success: "#32d74b"
        property color warning: "#ffd60a"
        property color danger: "#ff453a"
        property color info: "#64d2ff"

        readonly property color islandGround: "#000000"
        readonly property real glassTintFactor: 0.22
        readonly property real glassOpacity: 0.90
        readonly property color glassGround: Qt.rgba(
            accent.r * glassTintFactor,
            accent.g * glassTintFactor,
            accent.b * glassTintFactor,
            glassOpacity
        )
        readonly property color liquidGround: Qt.rgba(0.06, 0.07, 0.09, 0.66)
        readonly property color glassGroundLight: Qt.rgba(
            0.94 + accent.r * 0.05,
            0.95 + accent.g * 0.04,
            0.97 + accent.b * 0.03,
            0.84
        )
        readonly property color liquidGroundLight: Qt.rgba(0.96, 0.97, 0.99, 0.74)

        readonly property color focusRing: Qt.rgba(accent.r, accent.g, accent.b, 0.55)
        readonly property color scrim: Qt.rgba(0, 0, 0, 0.40)
        readonly property color hairline: Qt.rgba(1, 1, 1, 0.12)

        Behavior on bg            { enabled: !root.reducedMotion && !root.gameMode; ColorAnimation { duration: root.motion.palette } }
        Behavior on surface       { enabled: !root.reducedMotion && !root.gameMode; ColorAnimation { duration: root.motion.palette } }
        Behavior on surfaceRaised { enabled: !root.reducedMotion && !root.gameMode; ColorAnimation { duration: root.motion.palette } }
        Behavior on surfaceHover  { enabled: !root.reducedMotion && !root.gameMode; ColorAnimation { duration: root.motion.palette } }
        Behavior on surfaceActive { enabled: !root.reducedMotion && !root.gameMode; ColorAnimation { duration: root.motion.palette } }
        Behavior on border        { enabled: !root.reducedMotion && !root.gameMode; ColorAnimation { duration: root.motion.palette } }
        Behavior on borderStrong  { enabled: !root.reducedMotion && !root.gameMode; ColorAnimation { duration: root.motion.palette } }
        Behavior on text          { enabled: !root.reducedMotion && !root.gameMode; ColorAnimation { duration: root.motion.palette } }
        Behavior on paletteMuted  { enabled: !root.reducedMotion && !root.gameMode; ColorAnimation { duration: root.motion.palette } }
        Behavior on accent        { enabled: !root.reducedMotion && !root.gameMode; ColorAnimation { duration: root.motion.palette } }
        Behavior on accentHover   { enabled: !root.reducedMotion && !root.gameMode; ColorAnimation { duration: root.motion.palette } }
    }

    component SpaceTokens: QtObject {
        readonly property real xxs: root.px(2)
        readonly property real xs: root.px(4)
        readonly property real sm: root.px(8 * root.densityFactor)
        readonly property real md: root.px(12 * root.densityFactor)
        readonly property real lg: root.px(16 * root.densityFactor)
        readonly property real xl: root.px(20 * root.densityFactor)
        readonly property real xxl: root.px(24 * root.densityFactor)
    }

    component SizeTokens: QtObject {
        readonly property real barHeight: root.barHeightOverride > 0
            ? root.px(root.barHeightOverride) : root.px(32)
        readonly property real controlSm: root.px(28 * root.densityFactor)
        readonly property real controlMd: root.px(36 * root.densityFactor)
        readonly property real controlLg: root.px(44 * root.densityFactor)

        readonly property real iconXs: root.px(12)
        readonly property real iconSm: root.px(14)
        readonly property real iconMd: root.px(16)
        readonly property real iconLg: root.px(20)
        readonly property real iconXl: root.px(24)

        readonly property real hitMin: root.px(28)
        readonly property real panelSm: root.px(380)
        readonly property real panelMd: root.px(560)
        readonly property real panelLg: root.px(940)
        readonly property real menuWidth: root.px(250)
    }

    component RadiusTokens: QtObject {
        readonly property real none: 0
        readonly property real xs: root.followCompositorRadius
            ? Math.min(root.px(4), root.compositorRounding) : root.px(4)
        readonly property real sm: root.followCompositorRadius
            ? Math.min(root.px(8), root.compositorRounding) : root.px(8)
        readonly property real md: root.followCompositorRadius
            ? Math.min(root.px(12), root.compositorRounding) : root.px(12)
        readonly property real lg: root.followCompositorRadius
            ? Math.min(root.px(18), root.compositorRounding) : root.px(18)
        readonly property real xl: root.followCompositorRadius
            ? Math.min(root.px(22), root.compositorRounding) : root.px(22)
        readonly property real notch: root.px(6)
        readonly property real pill: 999
    }

    component TypeTokens: QtObject {
        readonly property var installedFonts: Qt.fontFamilies()

        function resolveFont(stack: string): string {
            const parts = stack.split(",")
            for (let i = 0; i < parts.length; ++i) {
                const candidate = parts[i].trim()
                if (candidate.length > 0 && installedFonts.indexOf(candidate) !== -1)
                    return candidate
            }
            return parts.length > 0 ? parts[parts.length - 1].trim() : "sans-serif"
        }

        property string uiStack: "Inter, Adwaita Sans, Google Sans Text, Cantarell, SF Pro Text, Noto Sans, sans-serif"
        property string displayStack: "Inter Display, PP Neue Machina, Inter, Adwaita Sans, sans-serif"
        property string monoStack: "JetBrainsMono Nerd Font, JetBrainsMono Nerd Font Mono, Adwaita Mono, JetBrains Mono, monospace"
        property string scriptStack: "Grape Nuts, Georgia, serif"

        readonly property string uiFamily: resolveFont(uiStack)
        readonly property string displayFamily: resolveFont(displayStack)
        readonly property string monoFamily: resolveFont(monoStack)
        readonly property string scriptFamily: resolveFont(scriptStack)

        readonly property int caption: Math.round(root.px(11))
        readonly property int sm: Math.round(root.px(12))
        readonly property int body: Math.round(root.px(13))
        readonly property int subtitle: Math.round(root.px(14))
        readonly property int title: Math.round(root.px(16))
        readonly property int h2: Math.round(root.px(20))
        readonly property int h1: Math.round(root.px(24))
        readonly property int display: Math.round(root.px(56))
    }

    component MotionTokens: QtObject {
        readonly property real effectiveMultiplier: (root.reducedMotion || root.gameMode)
            ? 0 : root.motionScale

        readonly property int instant: 0
        readonly property int fast: Math.round(120 * effectiveMultiplier)
        readonly property int normal: Math.round(200 * effectiveMultiplier)
        readonly property int slow: Math.round(280 * effectiveMultiplier)
        readonly property int morph: Math.round(360 * effectiveMultiplier)
        readonly property int palette: Math.round(260 * effectiveMultiplier)

        readonly property int easeOut: Easing.OutCubic
        readonly property int easeIn: Easing.InCubic
        readonly property int easeInOut: Easing.InOutCubic
        readonly property int easeSpring: Easing.OutBack

        readonly property int dwellIntent: 80
        readonly property int hoverGrace: 260
        readonly property int railHideDelay: 900
    }

    component ElevationTokens: QtObject {
        readonly property real shadowRange: root.px(14)
        readonly property real shadowSpread: root.px(4)
        readonly property real shadowOpacity: 0.50
        readonly property color shadowColor: "#000000"
        readonly property real glassSheenDepth: root.px(48)
        readonly property real litRim: 0.88
        readonly property real litTrace: 0.06
        readonly property bool shadowsActive: root.shadowsEnabled && !root.gameMode
    }

    readonly property ColorTokens color: ColorTokens {}
    readonly property SpaceTokens space: SpaceTokens {}
    readonly property SizeTokens size: SizeTokens {}
    readonly property RadiusTokens radius: RadiusTokens {}
    readonly property TypeTokens type: TypeTokens {}
    readonly property MotionTokens motion: MotionTokens {}
    readonly property ElevationTokens elevation: ElevationTokens {}

    // ── THEME APPLICATION ───────────────────────────────────────────────────

    function applyPalette(colors: var, paletteId: string, paletteName: string, mode: string): void {
        if (!colors)
            return
        if (paletteId)
            root.activePaletteId = paletteId
        if (paletteName)
            root.activePaletteName = paletteName
        if (mode)
            root.activeMode = mode

        if (colors.bg)            root.color.bg = colors.bg
        if (colors.surface)       root.color.surface = colors.surface
        if (colors.surfaceRaised) root.color.surfaceRaised = colors.surfaceRaised
        if (colors.surfaceHover)  root.color.surfaceHover = colors.surfaceHover
        if (colors.surfaceActive) root.color.surfaceActive = colors.surfaceActive
        if (colors.border)        root.color.border = colors.border
        if (colors.borderStrong)  root.color.borderStrong = colors.borderStrong
        if (colors.text)          root.color.text = colors.text
        if (colors.textMuted)     root.color.paletteMuted = colors.textMuted
        if (colors.accent)        root.color.accent = colors.accent
        if (colors.accentHover)   root.color.accentHover = colors.accentHover
        if (colors.red)           root.color.danger = colors.red
        if (colors.green)         root.color.success = colors.green
        if (colors.yellow)        root.color.warning = colors.yellow
        if (colors.blue)          root.color.info = colors.blue
    }

    function selectPalette(paletteId: string): void {
        const entry = Palettes.byId(paletteId)
        if (!entry)
            return
        root.applyPalette(entry.colors, entry.id, entry.name, entry.mode)
    }
}
