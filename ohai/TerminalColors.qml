import QtQuick
import Quickshell
import Quickshell.Io

// TerminalColors - Parses system terminal colors from common config locations
// Provides ANSI colors 0-15 with named accessors for severity-based theming
//
// Color sources (in priority order):
// 1. ~/.cache/wal/colors (pywal)
// 2. ~/.Xresources
// 3. Hardcoded fallbacks

QtObject {
    id: termColors

    // Home directory from environment
    readonly property string home: Quickshell.env("HOME") || "/home"

    // ANSI color palette (0-15)
    property var colors: []

    // Named color accessors - Normal variants (0-7)
    readonly property color black:   colors[0] || "#1a1b26"
    readonly property color red:     colors[1] || "#f7768e"
    readonly property color green:   colors[2] || "#9ece6a"
    readonly property color yellow:  colors[3] || "#e0af68"
    readonly property color blue:    colors[4] || "#7aa2f7"
    readonly property color magenta: colors[5] || "#bb9af7"
    readonly property color cyan:    colors[6] || "#7dcfff"
    readonly property color white:   colors[7] || "#a9b1d6"

    // Named color accessors - Bright variants (8-15)
    readonly property color brightBlack:   colors[8]  || "#414868"
    readonly property color brightRed:     colors[9]  || "#f7768e"
    readonly property color brightGreen:   colors[10] || "#9ece6a"
    readonly property color brightYellow:  colors[11] || "#e0af68"
    readonly property color brightBlue:    colors[12] || "#7aa2f7"
    readonly property color brightMagenta: colors[13] || "#bb9af7"
    readonly property color brightCyan:    colors[14] || "#7dcfff"
    readonly property color brightWhite:   colors[15] || "#c0caf5"

    // Background and foreground (if available from theme)
    property color background: "#1a1b26"
    property color foreground: "#c0caf5"

    // Severity-based color getters
    // Returns [normal, bright] color pair for a severity level
    function forSeverity(severity: string): var {
        if (severity === "crit") {
            return { normal: red, bright: brightRed };
        }
        if (severity === "warn") {
            return { normal: yellow, bright: brightYellow };
        }
        // Default: info
        return { normal: blue, bright: brightBlue };
    }

    // Get the accent color for a severity (bright variant for UI elements)
    function accentFor(severity: string): color {
        return forSeverity(severity).bright;
    }

    // Get the tint color for a severity (normal variant for image tinting)
    function tintFor(severity: string): color {
        return forSeverity(severity).normal;
    }

    // Internal: Parse colors from pywal format (one hex color per line)
    function parsePywalColors(content: string): void {
        const lines = content.trim().split("\n");
        const parsed = [];
        for (let i = 0; i < Math.min(lines.length, 16); i++) {
            const line = lines[i].trim();
            if (line.match(/^#[0-9a-fA-F]{6}$/)) {
                parsed.push(line);
            }
        }
        if (parsed.length >= 16) {
            colors = parsed;
            console.log("TerminalColors: Loaded", parsed.length, "colors from pywal");
        }
    }

    // Internal: Parse colors from Xresources format
    function parseXresources(content: string): void {
        const parsed = new Array(16).fill(null);
        const lines = content.split("\n");

        for (const line of lines) {
            // Match patterns like: *.color4: #7aa2f7 or *color4: #7aa2f7
            const match = line.match(/^\*\.?color(\d+):\s*(#[0-9a-fA-F]{6})/i);
            if (match) {
                const idx = parseInt(match[1]);
                if (idx >= 0 && idx < 16) {
                    parsed[idx] = match[2];
                }
            }
            // Also check for background/foreground
            const bgMatch = line.match(/^\*\.?background:\s*(#[0-9a-fA-F]{6})/i);
            if (bgMatch) background = bgMatch[1];
            const fgMatch = line.match(/^\*\.?foreground:\s*(#[0-9a-fA-F]{6})/i);
            if (fgMatch) foreground = fgMatch[1];
        }

        // Only use if we got a reasonable number of colors
        const validCount = parsed.filter(c => c !== null).length;
        if (validCount >= 8) {
            colors = parsed.map((c, i) => c || colors[i] || "#888888");
            console.log("TerminalColors: Loaded", validCount, "colors from Xresources");
        }
    }

    // File readers for color sources
    property var pywalReader: FileView {
        id: pywalFile
        path: termColors.home + "/.cache/wal/colors"
        preload: true
        onLoaded: {
            const content = pywalFile.text();
            if (content && content.trim()) {
                termColors.parsePywalColors(content);
            }
        }
    }

    property var xresourcesReader: FileView {
        id: xresourcesFile
        path: termColors.home + "/.Xresources"
        preload: true
        // Only read if pywal didn't provide colors
        onLoaded: {
            if (termColors.colors.length < 16) {
                const content = xresourcesFile.text();
                if (content && content.trim()) {
                    termColors.parseXresources(content);
                }
            }
        }
    }

    // Initialize with Tokyo Night defaults (a popular dark theme)
    Component.onCompleted: {
        colors = [
            "#1a1b26", // 0  black
            "#f7768e", // 1  red
            "#9ece6a", // 2  green
            "#e0af68", // 3  yellow
            "#7aa2f7", // 4  blue
            "#bb9af7", // 5  magenta
            "#7dcfff", // 6  cyan
            "#a9b1d6", // 7  white
            "#414868", // 8  bright black
            "#f7768e", // 9  bright red
            "#9ece6a", // 10 bright green
            "#e0af68", // 11 bright yellow
            "#7aa2f7", // 12 bright blue
            "#bb9af7", // 13 bright magenta
            "#7dcfff", // 14 bright cyan
            "#c0caf5"  // 15 bright white
        ];
    }
}
