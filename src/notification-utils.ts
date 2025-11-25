import { exec, execFile } from 'child_process';
import fs from 'fs/promises';
import { homedir } from 'os';
import { dirname, join } from 'path';
import { promisify } from 'util';

const execAsync = promisify(exec);
const execFileAsync = promisify(execFile);

export interface PopupNotificationOptions {
  urgency: 'low' | 'normal' | 'critical';
  timeout: number;
  icon?: string;
}

export type WaybarSeverity = 'info' | 'warn' | 'crit';

export interface WaybarMessageOptions {
  text?: string;
  tooltip?: string;
  severity?: WaybarSeverity;
  pulse?: boolean;
  durationSeconds?: number;
  stateFilePath?: string;
  modeFilePath?: string;
  stampFilePath?: string;
  enableModeToggle?: boolean;
}

const defaultWaybarStateFile = '/tmp/waybar-mcp.json';
const defaultWaybarModeFile = join(
  homedir(),
  '.config',
  'waybar',
  'mcp-mode.json'
);
const defaultWaybarStampFile = '/tmp/waybar-mcp.stamp';

const READY_WAYBAR_PAYLOAD = {
  text: '󰂚 ready',
  tooltip: 'Waiting for MCP notifications',
  class: '',
};

async function ensureParentDir(path: string): Promise<void> {
  await fs.mkdir(dirname(path), { recursive: true });
}

async function writeJson(filePath: string, data: unknown): Promise<void> {
  await ensureParentDir(filePath);
  await fs.writeFile(filePath, JSON.stringify(data), 'utf8');
}

async function getMtime(filePath: string): Promise<number | null> {
  try {
    const stats = await fs.stat(filePath);
    return stats.mtimeMs;
  } catch {
    return null;
  }
}

async function refreshWaybarModule(): Promise<boolean> {
  try {
    await execAsync('pkill -RTMIN+8 waybar');
    return true;
  } catch {
    return false;
  }
}

async function reloadWaybarConfig(): Promise<boolean> {
  try {
    await execAsync('pkill -SIGUSR2 waybar');
    return true;
  } catch {
    return false;
  }
}

export async function setWaybarMode(
  mode: 'default' | 'mcp',
  modeFilePath: string = defaultWaybarModeFile
): Promise<boolean> {
  if (currentWaybarMode === mode) {
    return true;
  }

  try {
    await writeJson(modeFilePath, { mode });
    const reloaded = await reloadWaybarConfig();
    if (reloaded) {
      currentWaybarMode = mode;
    }
    return reloaded;
  } catch (error) {
    console.error('Failed to set Waybar mode:', error);
    return false;
  }
}

export async function clearWaybarMessage(
  stateFilePath: string = defaultWaybarStateFile,
  modeFilePath: string = defaultWaybarModeFile
): Promise<void> {
  await writeJson(stateFilePath, READY_WAYBAR_PAYLOAD);
  await refreshWaybarModule();
  await setWaybarMode('default', modeFilePath);
}

export async function displayWaybarMessage(
  message: string,
  options: WaybarMessageOptions = {}
): Promise<string> {
  const {
    text,
    tooltip,
    severity = 'info',
    pulse = false,
    durationSeconds = 8,
    stateFilePath = defaultWaybarStateFile,
    modeFilePath = defaultWaybarModeFile,
    stampFilePath = defaultWaybarStampFile,
    enableModeToggle = true,
  } = options;

  const classes = ['active', severity];
  if (pulse) {
    classes.push('pulse');
  }

  const payload = {
    text: text ?? ` ${message}`,
    tooltip: tooltip ?? message,
    class: classes.join(' '),
  };

  await writeJson(stateFilePath, payload);
  const beforeStamp = await getMtime(stampFilePath);
  const refreshed = await refreshWaybarModule();
  const afterStamp = await getMtime(stampFilePath);
  const moduleUpdated =
    beforeStamp !== null && afterStamp !== null ? afterStamp > beforeStamp : false;

  let modeChanged = true;
  if (enableModeToggle) {
    modeChanged = await setWaybarMode('mcp', modeFilePath);
  }

  // Fallback: if signal succeeded but module did not refresh, force a config reload once.
  if (refreshed && !moduleUpdated) {
    const reloaded = await reloadWaybarConfig();
    if (reloaded) {
      modeChanged = true;
    }
  }

  if (waybarClearTimer) {
    clearTimeout(waybarClearTimer);
  }

  const cleanup = async () => {
    try {
      await clearWaybarMessage(stateFilePath, modeFilePath);
    } catch (error) {
      console.error('Failed to clear Waybar MCP message:', error);
    }
  };

  waybarClearTimer = setTimeout(() => {
    void cleanup();
    waybarClearTimer = null;
  }, durationSeconds * 1000);

  const statusParts = [
    `Waybar message queued (${severity}, ${durationSeconds}s${pulse ? ', pulse' : ''})`,
  ];
  if (!refreshed) {
    statusParts.push('warning: waybar not signaled (is it running?)');
  }
  if (refreshed && !moduleUpdated) {
    statusParts.push(
      'warning: waybar did not refresh on signal (check module signal number/config)'
    );
  }
  if (enableModeToggle && !modeChanged) {
    statusParts.push('warning: waybar mode reload failed or mode file not writable');
  }

  return statusParts.join(' | ');
}

let waybarClearTimer: NodeJS.Timeout | null = null;
let currentWaybarMode: 'default' | 'mcp' = 'default';

export async function showPopupNotification(
  title: string,
  message: string,
  options: PopupNotificationOptions
): Promise<string> {
  try {
    const args = [
      `--urgency=${options.urgency}`,
      `--expire-time=${options.timeout}`,
    ];

    if (options.icon) {
      args.push(`--icon=${options.icon}`);
    }

    args.push('--app-name=Cursor MCP');

    await execFileAsync('notify-send', [...args, title, message]);

    return `Notification sent with urgency: ${options.urgency}, timeout: ${options.timeout}ms`;
  } catch (error) {
    try {
      const dunstArgs = [`-u`, options.urgency, `-t`, `${options.timeout}`];

      if (options.icon) {
        dunstArgs.push(`-I`, options.icon);
      }

      await execFileAsync('dunstify', [...dunstArgs, title, message]);

      return `Notification sent via dunstify with urgency: ${options.urgency}, timeout: ${options.timeout}ms`;
    } catch (dunstError) {
      const notifyError =
        error instanceof Error ? error.message : String(error);
      const fallbackError =
        dunstError instanceof Error ? dunstError.message : String(dunstError);
      throw new Error(
        `Both notify-send and dunstify failed. notify-send error: ${notifyError}, dunstify error: ${fallbackError}`
      );
    }
  }
}
