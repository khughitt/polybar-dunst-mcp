# Polybar Notification MCP

An MCP (Model Context Protocol) server for displaying messages in polybar and showing popup notifications on Linux systems.

Based on [neotanx/neomcps - sound notification mcp](https://github.com/neotanx/neo-mcps/tree/main/servers/sound-notification).

## Features

- **Polybar Integration**: Display messages in polybar status bar with customizable colors and duration
- **Popup Notifications**: Show desktop notifications using notify-send/dunst
- **Flexible Configuration**: Customize colors, duration, urgency, and icons
- **Multiple Fallbacks**: Graceful fallbacks for different notification systems

## Installation

```bash
npm install
npm run build
```

## Usage

### Available Tools

#### `display_polybar_message`
Display a message in polybar status bar.

Parameters:
- `message` (string): The message to display
- `duration` (number, optional): Duration in seconds (default: 5)
- `color` (string, optional): Text color (default: #ffffff)
- `background` (string, optional): Background color (default: #333333)

#### `show_popup_notification`
Show a desktop popup notification.

Parameters:
- `title` (string): Notification title
- `message` (string): Notification message
- `urgency` (string, optional): "low", "normal", or "critical" (default: normal)
- `timeout` (number, optional): Timeout in milliseconds (default: 5000)
- `icon` (string, optional): Icon name or path

### Polybar Setup

To integrate with polybar, add this module to your polybar config, e.g.:

```ini
[module/mcp-notification]
type = custom/script
exec = cat /tmp/polybar-mcp-message 2>/dev/null | jq -r '.message // ""' 2>/dev/null || echo ""
interval = 1
format = <label>
format-prefix = "🤖 "
format-underline = ${xrdb:color7}
label = %output%
```

### Cursor Integration

To configure Cursor to use this MCP server:

1. **Open Cursor Settings**: Press `Ctrl+,` (or `Cmd+,` on Mac) to open settings
2. **Navigate to MCP Settings**: Search for "MCP" in the settings or look for "Model Context Protocol" settings
3. **Add the MCP Server Configuration**: Add the following to your MCP settings configuration:

```json
{
  "mcpServers": {
    "polybar-notification": {
      "command": "node",
      "args": ["~/cursor-polybar-mcp/bin/polybar-mcp"],
      "env": {}
    }
  }
}
```

Next, in `Cursor Settings` -> `Rules`, add a User rule to tell cursor when to use the MCP, e.g.:

```
Always, after completing any user request (success or failure), call the "display_polybar_message" tool with a summary of the last action or result, before waiting for further user input.
```

#### Troubleshooting Cursor Integration:

- **Restart Cursor** after adding the MCP configuration
- **Check the Developer Console** (`Help` → `Toggle Developer Tools`) for any MCP connection errors
- **Verify the path** to the `bin/polybar-mcp` file is correct
- **Ensure the project is built** by running `npm run build` before configuring Cursor
- **Test the MCP server manually** by running: `node bin/polybar-mcp` to ensure it starts without errors

The server supports path expansion for `~/` and `$HOME/` paths, making configuration more flexible across different environments.

## Development

```bash
npm run dev      # Watch mode
npm run build    # Build
npm run lint     # Lint code
npm run format   # Format code
```

## Requirements

- Linux system
- polybar (optional, for status bar integration)
- notify-send or dunstify (for popup notifications)
- Node.js 18+
