pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property var list: [
        {
            id: "monochrome_dark",
            name: "Monochrome Dark",
            mode: "dark",
            swatches: ["#d4d4d4", "#e6e6e6", "#61afef", "#98c379"],
            colors: {
                bg: "#0b0c0d",
                surface: "#141414",
                surfaceRaised: "#1a1b1f",
                surfaceHover: "#222429",
                surfaceActive: "#2c3036",
                border: "#262626",
                borderStrong: "#3a3e44",
                text: "#e6e6e6",
                textMuted: "#8e8e93",
                accent: "#d4d4d4",
                accentHover: "#ffffff",
                red: "#e06c75",
                green: "#98c379",
                yellow: "#e5c07b",
                blue: "#61afef"
            }
        },
        {
            id: "catppuccin_mocha",
            name: "Catppuccin Mocha",
            mode: "dark",
            swatches: ["#89b4fa", "#f5c2e7", "#a6e3a1", "#fab387"],
            colors: {
                bg: "#11111b",
                surface: "#181825",
                surfaceRaised: "#1e1e2e",
                surfaceHover: "#313244",
                surfaceActive: "#45475a",
                border: "#313244",
                borderStrong: "#45475a",
                text: "#cdd6f4",
                textMuted: "#a6adc8",
                accent: "#89b4fa",
                accentHover: "#b4befe",
                red: "#f38ba8",
                green: "#a6e3a1",
                yellow: "#f9e2af",
                blue: "#89b4fa"
            }
        },
        {
            id: "catppuccin_latte",
            name: "Catppuccin Latte",
            mode: "light",
            swatches: ["#1e66f5", "#8839ef", "#40a02b", "#ea76cb"],
            colors: {
                bg: "#dce0e8",
                surface: "#e6e9ef",
                surfaceRaised: "#eff1f5",
                surfaceHover: "#ccd0da",
                surfaceActive: "#bcc0cc",
                border: "#bcc0cc",
                borderStrong: "#9ca0b0",
                text: "#4c4f69",
                textMuted: "#6c6f85",
                accent: "#1e66f5",
                accentHover: "#04a5e5",
                red: "#d20f39",
                green: "#40a02b",
                yellow: "#df8e1d",
                blue: "#1e66f5"
            }
        },
        {
            id: "tokyo_night",
            name: "Tokyo Night",
            mode: "dark",
            swatches: ["#7aa2f7", "#bb9af7", "#9ece6a", "#f7768e"],
            colors: {
                bg: "#15161e",
                surface: "#1a1b26",
                surfaceRaised: "#1f2335",
                surfaceHover: "#24283b",
                surfaceActive: "#292e42",
                border: "#292e42",
                borderStrong: "#3b4261",
                text: "#c0caf5",
                textMuted: "#7982a9",
                accent: "#7aa2f7",
                accentHover: "#bb9af7",
                red: "#f7768e",
                green: "#9ece6a",
                yellow: "#e0af68",
                blue: "#7aa2f7"
            }
        },
        {
            id: "nord",
            name: "Nord",
            mode: "dark",
            swatches: ["#88c0d0", "#81a1c1", "#a3be8c", "#bf616a"],
            colors: {
                bg: "#242933",
                surface: "#2e3440",
                surfaceRaised: "#353c4a",
                surfaceHover: "#3b4252",
                surfaceActive: "#434c5e",
                border: "#3b4252",
                borderStrong: "#4c566a",
                text: "#eceff4",
                textMuted: "#d8dee9",
                accent: "#88c0d0",
                accentHover: "#8fbcbb",
                red: "#bf616a",
                green: "#a3be8c",
                yellow: "#ebcb8b",
                blue: "#81a1c1"
            }
        },
        {
            id: "everforest_dark",
            name: "Everforest Dark",
            mode: "dark",
            swatches: ["#a7c080", "#83c092", "#dbbc7f", "#e67e80"],
            colors: {
                bg: "#1e2326",
                surface: "#272e33",
                surfaceRaised: "#2e383c",
                surfaceHover: "#374145",
                surfaceActive: "#414b50",
                border: "#374145",
                borderStrong: "#4f5b58",
                text: "#d3c6aa",
                textMuted: "#9da9a0",
                accent: "#a7c080",
                accentHover: "#83c092",
                red: "#e67e80",
                green: "#a7c080",
                yellow: "#dbbc7f",
                blue: "#7fbbb3"
            }
        },
        {
            id: "nightfox",
            name: "Nightfox",
            mode: "dark",
            swatches: ["#719cd6", "#7ad4d6", "#81b29a", "#c94f6d"],
            colors: {
                bg: "#131a24",
                surface: "#192330",
                surfaceRaised: "#252f3c",
                surfaceHover: "#313b48",
                surfaceActive: "#3d4754",
                border: "#2b3b51",
                borderStrong: "#495360",
                text: "#c0c8d5",
                textMuted: "#71839b",
                accent: "#719cd6",
                accentHover: "#7ad4d6",
                red: "#c94f6d",
                green: "#81b29a",
                yellow: "#dbc074",
                blue: "#719cd6"
            }
        },
        {
            id: "gruvbox_dark",
            name: "Gruvbox Dark",
            mode: "dark",
            swatches: ["#d79921", "#83a598", "#b8bb26", "#fb4934"],
            colors: {
                bg: "#1d2021",
                surface: "#282828",
                surfaceRaised: "#32302f",
                surfaceHover: "#3c3836",
                surfaceActive: "#504945",
                border: "#3c3836",
                borderStrong: "#504945",
                text: "#ebdbb2",
                textMuted: "#a89984",
                accent: "#d79921",
                accentHover: "#fabd2f",
                red: "#fb4934",
                green: "#b8bb26",
                yellow: "#fabd2f",
                blue: "#83a598"
            }
        },
        {
            id: "rose_pine",
            name: "Rosé Pine",
            mode: "dark",
            swatches: ["#ebbcba", "#f6c177", "#31748f", "#eb6f92"],
            colors: {
                bg: "#191724",
                surface: "#1f1d2e",
                surfaceRaised: "#26233a",
                surfaceHover: "#2a273f",
                surfaceActive: "#403d52",
                border: "#2a273f",
                borderStrong: "#403d52",
                text: "#e0def4",
                textMuted: "#908caa",
                accent: "#ebbcba",
                accentHover: "#f6c177",
                red: "#eb6f92",
                green: "#31748f",
                yellow: "#f6c177",
                blue: "#9ccfd8"
            }
        }
    ]

    function byId(paletteId: string): var {
        return root.list.find(entry => entry.id === paletteId) ?? null
    }

    function relativeLuminance(c: color): real {
        const linearize = function(channel: real): real {
            return channel <= 0.03928
                ? channel / 12.92
                : Math.pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(c.r) + 0.7152 * linearize(c.g) + 0.0722 * linearize(c.b)
    }

    function contrastRatio(a: color, b: color): real {
        const la = root.relativeLuminance(a)
        const lb = root.relativeLuminance(b)
        const lighter = Math.max(la, lb)
        const darker = Math.min(la, lb)
        return (lighter + 0.05) / (darker + 0.05)
    }

    function contrastInk(bgColor: color, darkInk: color, lightInk: color): color {
        return root.contrastRatio(bgColor, darkInk) >= root.contrastRatio(bgColor, lightInk)
            ? darkInk : lightInk
    }
}
