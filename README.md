# Waybar / notify-send MCP

An MCP (Model Context Protocol) server that can notify via Waybar and/or desktop popups (`notify-send` / dunst).

Based on [neotanx/neomcps - sound notification mcp](https://github.com/neotanx/neo-mcps/tree/main/servers/sound-notification).

## Installation

```bash
npm install
npm run build
```

## Usage

### Available Tools

#### `notify_user`
Notify the user via Waybar and/or popup.

Parameters:
- `message` (string, required): Message body.
- `title` (string, optional): Popup title (defaults to `message`).
- `channels` (array, optional): Any of `["waybar", "popup"]`. Defaults to `["waybar","popup"]` (configurable via `MCP_NOTIFY_DEFAULT_CHANNELS`, comma-separated).
- `urgency` (string, optional): Popup urgency (`low|normal|critical`, default `normal`).
- `timeoutMs` (number, optional): Popup timeout in ms (default `5000`).
- `icon` (string, optional): Popup icon name/path.
- `waybar` (object, optional):
  - `severity` (`info|warn|crit`): Accent/severity class (default `info`).
  - `pulse` (bool): Enable slow pulse animation on the module.
  - `durationSeconds` (number): Seconds before auto-clear and mode reset (default `8`).
  - `text` (string): Override bar text (defaults to ` {message}`).
  - `tooltip` (string): Override tooltip (defaults to `message`).

Defaults can be overridden globally by setting `MCP_NOTIFY_DEFAULT_CHANNELS` (e.g., `MCP_NOTIFY_DEFAULT_CHANNELS=waybar` to disable popups).

### Waybar Setup (Recommended)

1. Copy or symlink `waybar/` to `~/.config/waybar/` (or merge into your existing config).
2. Ensure `waybar/scripts/waybar-mcp.sh` is executable and available at `~/.config/waybar/scripts/waybar-mcp.sh`.
3. The provided `config.desktop`/`config.laptop` already:
   - Include `custom/mcp` in `modules-right`
   - Define a `mcp` bar mode and include `~/.config/waybar/mcp-mode.json`
4. Keep `~/.config/waybar/mcp-mode.json` present (default content provided in this repo) so reloads succeed.
5. Reload Waybar to pick up changes: `pkill -SIGUSR2 waybar`. The module updates on `pkill -RTMIN+8 waybar`.

Waybar module behavior:
- Inactive: shows `󰂚 ready` in muted color.
- Active: bell + message, underline + tint based on severity, optional pulse animation.
- Click (or right-click) clears the message and resets mode to default.

### Cursor Integration

To configure Cursor to use this MCP server:

1. **Open Cursor Settings**: Press `Ctrl+,` (or `Cmd+,` on Mac) to open settings
2. **Navigate to MCP Settings**: Search for "MCP" in the settings or look for "Model Context Protocol" settings
3. **Add the MCP Server Configuration**: Add the following to your MCP settings configuration:

```json
{
  "mcpServers": {
    "waybar-notify-mcp": {
      "command": "node",
      "args": ["~/waybar-notify-mcp/bin/waybar-notify-mcp"],
      "env": {}
    }
  }
}
```

Next, in `Cursor Settings` -> `Rules`, add a User rule to tell Cursor when to use the MCP, e.g.:

```
When you need user attention, call notify_user with channels ["waybar","popup"] and a concise summary.
```

#### Troubleshooting Cursor Integration:

- **Restart Cursor** after adding the MCP configuration
- **Check the Developer Console** (`Help` → `Toggle Developer Tools`) for any MCP connection errors
- **Verify the path** to the `bin/waybar-notify-mcp` file is correct
- **Ensure the project is built** by running `npm run build` before configuring Cursor
- **Test the MCP server manually** by running: `node bin/waybar-notify-mcp` to ensure it starts without errors

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
- Waybar (recommended) and/or notify-send/dunstify
- Node.js 18+
