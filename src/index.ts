#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { z } from 'zod';
import {
  displayWaybarMessage,
  showPopupNotification,
} from './notification-utils.js';
import { zodToJsonSchema } from 'zod-to-json-schema';

const server = new Server(
  {
    name: 'waybar-notify-mcp',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

const NotifyUserSchema = z.object({
  message: z.string().describe('Message body to display'),
  title: z
    .string()
    .optional()
    .describe('Popup notification title (defaults to message)'),
  channels: z
    .array(z.enum(['waybar', 'popup']))
    .optional()
    .describe('Destinations to notify; defaults to ["waybar","popup"]'),
  urgency: z
    .enum(['low', 'normal', 'critical'])
    .optional()
    .describe('Popup urgency (default: normal)'),
  timeoutMs: z
    .number()
    .optional()
    .describe('Popup timeout in milliseconds (default: 5000)'),
  icon: z.string().optional().describe('Popup icon name or path'),
  waybar: z
    .object({
      severity: z
        .enum(['info', 'warn', 'crit'])
        .optional()
        .describe('Waybar accent/severity'),
      pulse: z.boolean().optional().describe('Enable pulse animation'),
      durationSeconds: z
        .number()
        .optional()
        .describe('Seconds before auto-clear (default: 8)'),
      text: z
        .string()
        .optional()
        .describe('Waybar text override (default: bell + message)'),
      tooltip: z
        .string()
        .optional()
        .describe('Waybar tooltip override (default: message)'),
    })
    .optional()
    .describe('Waybar-specific options'),
});

function parseDefaultChannels(): Array<'waybar' | 'popup'> {
  const raw = process.env.MCP_NOTIFY_DEFAULT_CHANNELS;
  if (!raw) {
    return ['waybar', 'popup'];
  }
  const parsed = raw
    .split(',')
    .map((item) => item.trim())
    .filter(
      (item): item is 'waybar' | 'popup' =>
        item === 'waybar' || item === 'popup'
    );
  return parsed.length > 0 ? parsed : ['waybar', 'popup'];
}

const notifyUserJsonSchema = (zodToJsonSchema as (schema: unknown) => unknown)(
  NotifyUserSchema
);

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'notify_user',
        description:
          'Notify the user via Waybar and/or popup (notify-send/dunst) with a single call.',
        inputSchema: notifyUserJsonSchema,
      },
    ],
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'notify_user': {
        const { message, title, channels, urgency, timeoutMs, icon, waybar } =
          NotifyUserSchema.parse(args);

        const targets =
          channels && channels.length > 0 ? channels : parseDefaultChannels();
        const uniqueTargets = Array.from(new Set(targets));
        const results: string[] = [];

        if (uniqueTargets.includes('waybar')) {
          const waybarResult = await displayWaybarMessage(message, {
            severity: waybar?.severity,
            pulse: waybar?.pulse ?? false,
            durationSeconds: waybar?.durationSeconds,
            text: waybar?.text,
            tooltip: waybar?.tooltip,
          });
          results.push(`Waybar: ${waybarResult}`);
        }

        if (uniqueTargets.includes('popup')) {
          const popupResult = await showPopupNotification(
            title ?? message,
            message,
            {
              urgency: urgency ?? 'normal',
              timeout: timeoutMs ?? 5000,
              icon,
            }
          );
          results.push(`Popup: ${popupResult}`);
        }

        return {
          content: [
            {
              type: 'text',
              text: results.join(' | '),
            },
          ],
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

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Waybar Notification MCP Server running on stdio');
}

main().catch((error) => {
  console.error('Fatal error in main():', error);
  process.exit(1);
});
