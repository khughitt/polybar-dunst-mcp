#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { z } from 'zod';
import { zodToJsonSchema } from 'zod-to-json-schema';
import { execFile } from 'child_process';
import { promisify } from 'util';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const execFileAsync = promisify(execFile);

// Auto-discover shell.qml path relative to this module
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const SHELL_QML_PATH = join(__dirname, '..', 'ohai', 'shell.qml');

// Allow overriding qs path via env, fallback to common locations
const QS_PATH = process.env.QS_PATH ?? 'qs';
const QS_FALLBACK_PATHS = ['/usr/bin/qs', '/usr/local/bin/qs'];

async function findQsPath(): Promise<string> {
  // Try configured/default path first
  try {
    await execFileAsync('which', [QS_PATH]);
    return QS_PATH;
  } catch {
    // Try fallback paths
    for (const path of QS_FALLBACK_PATHS) {
      try {
        await execFileAsync('test', ['-x', path]);
        return path;
      } catch {
        continue;
      }
    }
  }
  return QS_PATH; // Return default, let it fail with helpful error
}

const server = new Server(
  { name: 'ohai-mcp', version: '2.0.0' },
  { capabilities: { tools: {} } }
);

// --- Schemas ---

const OhaiSchema = z.object({
  message: z.string().describe('Message body to display'),
  title: z.string().optional().describe('Popup title (defaults to message)'),
  severity: z
    .enum(['info', 'warn', 'crit'])
    .optional()
    .describe('Accent color severity (default: info)'),
  color: z
    .string()
    .optional()
    .describe('Custom accent color (CSS/hex; overrides severity)'),
  timeoutSeconds: z
    .number()
    .optional()
    .describe('Seconds before auto-hide (default: 8; 0 = persistent)'),
  pattern: z.string().optional().describe('Background pattern ID or path'),
  image: z.string().optional().describe('Image ID or path (default: ghost)'),
  workspace: z
    .string()
    .optional()
    .describe('Workspace to switch to on backtick'),
  app: z.string().optional().describe('App/window to focus on backtick'),
  transition: z
    .enum(['glow', 'ghost', 'ripple', 'none'])
    .optional()
    .describe('Entry transition effect (default: glow, or OHAI_TRANSITION env var)'),
});

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const ohaiJsonSchema = (zodToJsonSchema as (schema: any) => any)(OhaiSchema);

// --- Helpers ---

// Environment variables needed for QuickShell/Wayland to work properly
const QS_ENV_VARS = [
  'XDG_RUNTIME_DIR',
  'WAYLAND_DISPLAY',
  'DISPLAY',
  'HOME',
  'USER',
  'DBUS_SESSION_BUS_ADDRESS',
  'XDG_SESSION_TYPE',
  'XDG_CURRENT_DESKTOP',
  'HYPRLAND_INSTANCE_SIGNATURE',
];

function getQsEnv(): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const key of QS_ENV_VARS) {
    if (process.env[key]) {
      env[key] = process.env[key];
    }
  }
  // Ensure XDG_RUNTIME_DIR is set (fallback to /run/user/<uid>)
  if (!env.XDG_RUNTIME_DIR) {
    const uid = process.getuid?.() ?? 1000;
    env.XDG_RUNTIME_DIR = `/run/user/${uid}`;
  }
  return env;
}

async function qsIpcCall(
  target: string,
  fn: string,
  args: string[]
): Promise<{ success: boolean; output?: string; error?: string }> {
  const qsPath = await findQsPath();
  const cmdArgs = ['-p', SHELL_QML_PATH, 'ipc', 'call', target, fn, ...args];
  const env = getQsEnv();

  try {
    const { stdout, stderr } = await execFileAsync(qsPath, cmdArgs, { env });
    if (stderr) {
      console.error('[ohai] qs stderr:', stderr);
    }
    return { success: true, output: stdout.trim() };
  } catch (error: unknown) {
    // Extract detailed error info from execFile errors
    const execError = error as {
      code?: number;
      stderr?: string;
      stdout?: string;
      message?: string;
    };

    const details = [
      `exit code: ${execError.code ?? 'unknown'}`,
      execError.stderr ? `stderr: ${execError.stderr}` : null,
      execError.stdout ? `stdout: ${execError.stdout}` : null,
    ]
      .filter(Boolean)
      .join(', ');

    // Log full debug info
    console.error('[ohai] qs command failed');
    console.error('[ohai] args:', JSON.stringify(cmdArgs));
    console.error('[ohai] details:', details);

    const message = execError.message ?? String(error);
    return { success: false, error: `${message} (${details})` };
  }
}

async function isQuickshellReady(): Promise<boolean> {
  try {
    const qsPath = await findQsPath();
    const env = getQsEnv();
    const { stdout } = await execFileAsync(qsPath, ['-p', SHELL_QML_PATH, 'ipc', 'show'], { env });
    return stdout.includes('ohai');
  } catch {
    return false;
  }
}

// --- Tool Handlers ---

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'ohai',
      description:
        'Display a notification popup via Quickshell. Supports custom styling, severity colors, and Hyprland workspace/app focus on backtick. IMPORTANT: This tool uses MCP - call it with a JSON object containing the parameters (message, title, severity, etc.), NOT as a shell command. The MCP server handles IPC internally.',
      inputSchema: ohaiJsonSchema,
    },
    {
      name: 'ohai_status',
      description:
        'Check if the Quickshell notification daemon is running and the ohai IPC target is registered.',
      inputSchema: { type: 'object', properties: {} },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'ohai': {
        const params = OhaiSchema.parse(args);

        // Build IPC call arguments (all 10 params, empty string = use default)
        const defaultImage = process.env.OHAI_DEFAULT_IMAGE ?? '';
        const ipcArgs = [
          params.title ?? params.message, // title
          params.message, // body
          params.severity ?? '', // severity
          String(params.timeoutSeconds ?? 8), // timeoutSeconds
          params.pattern ?? '', // pattern
          params.image ?? defaultImage, // image
          params.workspace ?? '', // workspace
          params.app ?? '', // app
          params.color ?? '', // color
          params.transition ?? '', // transition (glow, ghost, ripple, none)
        ];

        const result = await qsIpcCall('ohai', 'notify', ipcArgs);

        if (result.success) {
          console.error('[ohai] notification sent via IPC');
          return {
            content: [{ type: 'text', text: 'Notification sent' }],
          };
        } else {
          console.error(`[ohai] IPC failed: ${result.error}`);
          return {
            content: [
              {
                type: 'text',
                text: `Failed to send notification: ${result.error}`,
              },
            ],
            isError: true,
          };
        }
      }

      case 'ohai_status': {
        const ready = await isQuickshellReady();

        return {
          content: [
            {
              type: 'text',
              text: ready
                ? 'Quickshell is running with ohai IPC target registered'
                : 'Quickshell ohai target not found - ensure quickshell is running with the ohai popup',
            },
          ],
          isError: !ready,
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    };
  }
});

// --- Main ---

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('ohai MCP server running on stdio');
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
