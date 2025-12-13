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

### `ohai_status`

Check if Quickshell is running with the ohai IPC target registered.

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
   qs ipc call ohai notify "Hello" "Test message" "info" 5 "" "" "" "" ""
   ```

4. Controls while popup is visible:
   - `Escape` - hide popup
   - Backtick (`) - switch to workspace or focus app (if configured), then hide

### Bundled Assets

**Patterns** (background overlays):
- `waves-01`, `grid-01`, `stripes-01`, `sunset-01`

**Images** (left panel):
- `ghost` (default), `claude`, `openai`

Use an absolute path for custom assets.

## Integration

Use `OHAI_DEFAULT_IMAGE` to set the default image per client.

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
        "OHAI_DEFAULT_IMAGE": "claude"
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
        "OHAI_DEFAULT_IMAGE": "claude"
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
```

### Auto-launch (Hyprland)

```
exec-once = qs -p /path/to/ohai-mcp/ohai/shell.qml
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `OHAI_DEFAULT_IMAGE` | Default image when `image` param is not specified (e.g., `claude`, `openai`, `ghost`) |

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
