# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ohai-mcp is an MCP (Model Context Protocol) server that displays notification popups via Quickshell on Linux/Wayland. It enables AI assistants like Claude Code to send visual notifications to the user's desktop.

## Commands

```bash
npm run build    # Compile TypeScript to dist/
npm run dev      # Watch mode for development
npm run lint     # ESLint check
npm run lint:fix # ESLint auto-fix
npm run format   # Prettier format
npm start        # Run the MCP server
```

## Architecture

### Two-Part System

1. **MCP Server** (`src/index.ts` → `dist/index.js`)
   - Node.js server using `@modelcontextprotocol/sdk`
   - Exposes `ohai` and `ohai_status` tools via MCP protocol
   - Communicates with Quickshell via `qs ipc call` subprocess

2. **Quickshell UI** (`ohai/shell.qml`)
   - QML-based notification popup with animations
   - Receives messages via IPC handler (target: "ohai")
   - Must be running separately: `qs -p /path/to/ohai/shell.qml`

### Data Flow

```
MCP Client → ohai-mcp (Node.js) → qs ipc call → Quickshell IPC → shell.qml popup
```

### Key Files

- `src/index.ts` - MCP server implementation, tool schemas, IPC wrapper
- `ohai/shell.qml` - Main notification UI, IPC handler, entry/exit animations
- `ohai/effects/GlitchEffect.qml` - Chromatic aberration shader wrapper
- `ohai/effects/RippleEcho.qml` - Ripple border animation component
- `ohai/shaders/glitch.frag` - GLSL fragment shader for glitch effect

### Quickshell IPC

The server calls `qs -p shell.qml ipc call ohai notify [args]` with 9 ordered string arguments:
title, body, severity, timeoutSeconds, pattern, image, workspace, app, color

### Environment Variables

- `OHAI_DEFAULT_IMAGE` - Default notification image (ghost, claude, openai)
- `QS_PATH` - Override path to `qs` binary
- Wayland env vars (`XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY`, etc.) are passed through

## QML Component Patterns

- Resolvers pattern: `QtObject` with `resolve()` function for asset path normalization
- Lazy loading: `LazyLoader { active: condition }` for deferred window creation
- Shader effects: Applied via `layer.enabled: true` + `layer.effect: Component {}`
- Animations: `SequentialAnimation`/`ParallelAnimation` with easing curves
