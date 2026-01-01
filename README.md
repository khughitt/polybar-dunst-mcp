# ohai-mcp

An MCP server that displays notification popups via Quickshell on Linux.

## Installation

```bash
npm install
npm run build
```

## Tools

### `ohai`

Display a notification popup.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `message` | string | yes | Message body |
| `title` | string | no | Popup title (defaults to message) |
| `severity` | `info` \| `warn` \| `crit` | no | Accent color (default: `info`) |
| `color` | string | no | Custom accent color (CSS/hex; overrides severity) |
| `timeoutSeconds` | number | no | Auto-hide delay (default: 8; 0 = persistent) |
| `pattern` | string | no | Background pattern ID or path |
| `image` | string | no | Image ID or path (default: `ghost`) |
| `workspace` | string | no | Workspace to switch to on backtick |
| `app` | string | no | App/window to focus on backtick |
| `transition` | `glow` \| `ghost` \| `ripple` \| `none` | no | Entry transition effect (default: `glow`) |

### `ohai_status`

Check if Quickshell is running with the ohai IPC target registered.

## Transition Effects

| Effect | Description |
|--------|-------------|
| `glow` | Soft blur glow pulse (default) |
| `ghost` | Expanding/fading copies of actual notification content |
| `ripple` | Border ripples emanating outward |
| `none` | No transition effect |

Set a default transition via environment variable:
```bash
export OHAI_TRANSITION=ghost
```

## Quickshell Setup

1. Start the popup daemon:
```bash
qs -p /path/to/ohai-mcp/ohai/shell.qml
```

2. Verify the IPC target is registered:
```bash
qs ipc show
# Should list: target ohai
```

3. Test manually:
```bash
qs ipc call ohai notify "Hello" "Test message" "info" 5 "" "" "" "" "" "glow"
```

4. Controls while popup is visible:
   - `Escape` - hide popup
   - Backtick (`) - switch to workspace or focus app (if configured), then hide

### Testing with `ohai-test`

A CLI helper for testing notification appearance:

```bash
bin/ohai-test [preset]           # Run a preset
bin/ohai-test custom [options]   # Custom notification
```

**Presets:**
| Preset | Description |
|--------|-------------|
| `info` | Basic info notification (default) |
| `warn` | Warning notification |
| `crit` | Critical notification |
| `long` | Long text (test layout) |
| `short` | Minimal notification |
| `claude` | Claude-themed |
| `openai` | OpenAI-themed |
| `grid` | Grid pattern background |
| `stripes` | Stripes pattern background |
| `waves` | Waves pattern background |
| `glow` | Test glow transition effect |
| `ghost` | Test ghost echo transition effect |
| `ripple` | Test ripple transition effect |
| `all` | Cycle through all presets |

**Custom options:**
```bash
bin/ohai-test custom \
  -t "Title" \
  -b "Body text" \
  -s warn \
  -i claude \
  -p grid-01 \
  -d 10 \
  -c "#ff00ff" \
  -x ghost
```

| Option | Description |
|--------|-------------|
| `-t, --title` | Title text |
| `-b, --body` | Body text |
| `-s, --severity` | `info` \| `warn` \| `crit` |
| `-i, --image` | Image ID or path |
| `-p, --pattern` | Pattern ID or path |
| `-d, --duration` | Timeout in seconds |
| `-c, --color` | Custom accent color (hex) |
| `-w, --workspace` | Workspace to switch on backtick |
| `-a, --app` | App to focus on backtick |
| `-x, --transition` | `glow` \| `ghost` \| `ripple` \| `none` |

### Bundled Assets

**Patterns** (background overlays):
- `waves-01`, `grid-01`, `stripes-01`, `sunset-01`

**Images** (left panel):
- `ghost` (default), `claude`, `openai`

Use an absolute path for custom assets.

## Integration

Use environment variables to configure defaults per client.

### Claude Code

`~/.claude.json`:
```json
{
  "mcpServers": {
    "ohai": {
      "type": "stdio",
      "command": "node",
      "args": ["/path/to/ohai-mcp/bin/ohai-mcp"],
      "env": {
        "OHAI_DEFAULT_IMAGE": "claude",
        "OHAI_TRANSITION": "glow"
      }
    }
  }
}
```

### Cursor

Add to MCP settings:
```json
{
  "mcpServers": {
    "ohai": {
      "command": "node",
      "args": ["/path/to/ohai-mcp/bin/ohai-mcp"],
      "env": {
        "OHAI_DEFAULT_IMAGE": "claude",
        "OHAI_TRANSITION": "ghost"
      }
    }
  }
}
```

### codex-cli

`~/.codex/config.toml`:
```toml
[mcp_servers.ohai]
command = "node"
args = ["/path/to/ohai-mcp/bin/ohai-mcp"]

[mcp_servers.ohai.env]
OHAI_DEFAULT_IMAGE = "openai"
OHAI_TRANSITION = "glow"
```

### Auto-launch (Hyprland)

```
exec-once = qs -p /path/to/ohai-mcp/ohai/shell.qml
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `OHAI_DEFAULT_IMAGE` | Default image when `image` param is not specified (e.g., `claude`, `openai`, `ghost`) |
| `OHAI_TRANSITION` | Default transition effect (e.g., `glow`, `ghost`, `ripple`, `none`) |

## Architecture

```
┌─────────────┐     qs ipc call      ┌─────────────────┐
│  MCP Client │ ──────────────────▶  │   Quickshell    │
│  (Claude)   │                      │   (shell.qml)   │
└─────────────┘                      └─────────────────┘
       │                                     │
       │                                     │
       ▼                                     ▼
┌─────────────┐                      ┌─────────────────┐
│  ohai-mcp   │                      │  IpcHandler     │
│  (Node.js)  │                      │  target: "ohai" │
└─────────────┘                      └─────────────────┘
```

The MCP server communicates with Quickshell via its built-in IPC mechanism (`qs ipc call`), which uses a Unix socket for instant, reliable delivery.

## Development

```bash
npm run dev      # Watch mode
npm run build    # Build
npm run lint     # Lint
npm run format   # Format
```

## Requirements

- Linux with Quickshell
- Node.js 18+
