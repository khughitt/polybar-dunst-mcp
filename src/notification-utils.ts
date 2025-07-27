import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export interface PolybarMessageOptions {
  duration: number;
  color: string;
  background: string;
}

export interface PopupNotificationOptions {
  urgency: 'low' | 'normal' | 'critical';
  timeout: number;
  icon?: string;
}

export async function displayPolybarMessage(
  message: string,
  options: PolybarMessageOptions
): Promise<string> {
  try {
    // Method 1: Try to send message to polybar via polybar-msg
    try {
      await execAsync(`polybar-msg hook polybar-notification-mcp 1`);

      // Write the message to /tmp/polybar-mcp-message (for polybar to read)
      await execAsync(`echo '{"message": "${message.replace(/'/g, "'\\''")}"}' > /tmp/polybar-mcp-message`);

      // Schedule cleanup after duration: clear the message
      setTimeout(async () => {
        try {
          await execAsync(`echo '{"message": ""}' > /tmp/polybar-mcp-message`);
          await execAsync(`polybar-msg hook polybar-notification-mcp 2`);
        } catch (error) {
          console.error('Error cleaning up polybar message:', error);
        }
      }, options.duration * 1000);

      return `Message sent to polybar via polybar-msg (duration: ${options.duration}s)`;
    } catch (polybarError) {
      // Method 2: Try to write to a named pipe or file that polybar might be monitoring
      try {
        const pipePath = '/tmp/polybar-mcp-pipe';
        const messageData = JSON.stringify({
          message,
          color: options.color,
          background: options.background,
          duration: options.duration,
          timestamp: Date.now(),
        });

        // Try to write to named pipe
        await execAsync(
          `echo '${messageData}' > ${pipePath} 2>/dev/null || true`
        );

        // Also write to a regular file as fallback
        await execAsync(`echo '${messageData}' > /tmp/polybar-mcp-message`);

        // Schedule cleanup after duration: clear the message
        setTimeout(async () => {
          try {
            const emptyMessageData = JSON.stringify({
              message: '',
              color: options.color,
              background: options.background,
              duration: 0,
              timestamp: Date.now(),
            });
            await execAsync(`echo '${emptyMessageData}' > ${pipePath} 2>/dev/null || true`);
            await execAsync(`echo '${emptyMessageData}' > /tmp/polybar-mcp-message`);
          } catch (cleanupError) {
            console.error('Error clearing polybar message (pipe/file):', cleanupError);
          }
        }, options.duration * 1000);

        return `Message written to polybar communication files`;
      } catch (fileError) {
        // Method 3: Use xsetroot to set window manager info (visible in some status bars)
        try {
          const displayMessage = `${message} [${new Date().toLocaleTimeString()}]`;
          await execAsync(`xsetroot -name "${displayMessage}"`);

          // Reset after duration
          setTimeout(async () => {
            try {
              await execAsync(`xsetroot -name ""`);
            } catch (error) {
              console.error('Error resetting xsetroot:', error);
            }
          }, options.duration * 1000);

          return `Message set via xsetroot (duration: ${options.duration}s)`;
        } catch (xsetError) {
          throw new Error(
            `All polybar methods failed. Last error: ${xsetError}`
          );
        }
      }
    }
  } catch (error) {
    throw new Error(
      `Failed to display polybar message: ${error instanceof Error ? error.message : String(error)}`
    );
  }
}

export async function showPopupNotification(
  title: string,
  message: string,
  options: PopupNotificationOptions
): Promise<string> {
  try {
    // Build notify-send command
    const args = [
      `--urgency=${options.urgency}`,
      `--expire-time=${options.timeout}`,
    ];

    if (options.icon) {
      args.push(`--icon="${options.icon}"`);
    }

    // Add app name for better identification
    args.push('--app-name="Cursor MCP"');

    const command = `notify-send ${args.join(' ')} "${title}" "${message}"`;

    await execAsync(command);

    return `Notification sent with urgency: ${options.urgency}, timeout: ${options.timeout}ms`;
  } catch (error) {
    // Fallback: try dunstify if notify-send fails
    try {
      const dunstArgs = [`-u ${options.urgency}`, `-t ${options.timeout}`];

      if (options.icon) {
        dunstArgs.push(`-I "${options.icon}"`);
      }

      const dunstCommand = `dunstify ${dunstArgs.join(' ')} "${title}" "${message}"`;
      await execAsync(dunstCommand);

      return `Notification sent via dunstify with urgency: ${options.urgency}, timeout: ${options.timeout}ms`;
    } catch (dunstError) {
      throw new Error(
        `Both notify-send and dunstify failed. notify-send error: ${error instanceof Error ? error.message : String(error)}, dunstify error: ${dunstError instanceof Error ? dunstError.message : String(dunstError)}`
      );
    }
  }
}
