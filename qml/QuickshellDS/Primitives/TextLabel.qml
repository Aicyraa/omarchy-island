import QtQuick
import "../Theme"

Text {
    id: root

    // "caption" | "sm" | "body" | "subtitle" | "title" | "h2" | "h1" | "display" | "mono" | "script"
    property string role: "body"
    // "primary" | "secondary" | "muted" | "disabled" | "accent" | "onAccent" | "success" | "warning" | "danger" | "info"
    property string tone: "primary"
    property bool tabular: false
    property bool singleLine: true

    font.family: {
        switch (root.role) {
        case "display": return Tokens.type.displayFamily
        case "mono":    return Tokens.type.monoFamily
        case "script":  return Tokens.type.scriptFamily
        default:        return Tokens.type.uiFamily
        }
    }

    font.pixelSize: {
        switch (root.role) {
        case "caption":  return Tokens.type.caption
        case "sm":       return Tokens.type.sm
        case "subtitle": return Tokens.type.subtitle
        case "title":    return Tokens.type.title
        case "h2":       return Tokens.type.h2
        case "h1":       return Tokens.type.h1
        case "display":  return Tokens.type.display
        default:         return Tokens.type.body
        }
    }

    font.weight: {
        switch (root.role) {
        case "h1":
        case "h2":
        case "title":    return Font.Medium
        default:         return Font.Normal
        }
    }

    font.features: root.tabular ? ({ "tnum": 1 }) : ({})
    textFormat: Text.PlainText
    elide: root.singleLine ? Text.ElideRight : Text.ElideNone
    wrapMode: root.singleLine ? Text.NoWrap : Text.WordWrap

    color: {
        switch (root.tone) {
        case "secondary": return Tokens.color.textSecondary
        case "muted":     return Tokens.color.textMuted
        case "disabled":  return Tokens.color.textDisabled
        case "accent":    return Tokens.color.accent
        case "onAccent":  return Tokens.color.onAccent
        case "success":   return Tokens.color.success
        case "warning":   return Tokens.color.warning
        case "danger":    return Tokens.color.danger
        case "info":      return Tokens.color.info
        default:          return Tokens.color.text
        }
    }
}
