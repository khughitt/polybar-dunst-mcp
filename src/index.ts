#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { z } from 'zod';
import { homedir } from 'os';
import { resolve } from 'path';
import {
  displayPolybarMessage,
  showPopupNotification,
} from './notification-utils.js';
import { zodToJsonSchema } from 'zod-to-json-schema';

function expandPath(inputPath: string): string {
  if (inputPath.startsWith('~/')) {
    return resolve(homedir(), inputPath.slice(2));
  }
  if (inputPath.includes('$HOME/')) {
    return inputPath.replace('$HOME', homedir());
  }
  return inputPath;
}

const server = new Server(
  {
    name: 'polybar-notification-mcp',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

const DisplayPolybarMessageSchema = z.object({
  message: z.string().describe('The message to display in polybar'),
  duration: z
    .number()
    .optional()
    .describe('Duration in seconds to display the message (default: 5)'),
  color: z
    .string()
    .optional()
    .describe('Text color for the message (default: #ffffff)'),
  background: z
    .string()
    .optional()
    .describe('Background color for the message (default: #333333)'),
});

const ShowPopupNotificationSchema = z.object({
  title: z.string().describe('The notification title'),
  message: z.string().describe('The notification message'),
  urgency: z
    .enum(['low', 'normal', 'critical'])
    .optional()
    .describe('Notification urgency level (default: normal)'),
  timeout: z
    .number()
    .optional()
    .describe('Notification timeout in milliseconds (default: 5000)'),
  icon: z
    .string()
    .optional()
    .describe('Icon name or path for the notification'),
});

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'display_polybar_message',
        description: 'Display a message in polybar status bar. Useful for notifying the user when an operation is complete or when waiting for user input.',
        inputSchema: zodToJsonSchema(DisplayPolybarMessageSchema),
      },
      {
        name: 'show_popup_notification',
        description: 'Show a popup notification using notify-send/dunst. Useful for notifying the user when an operation is complete or when waiting for user input.',
        inputSchema: zodToJsonSchema(ShowPopupNotificationSchema),
      },
    ],
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'display_polybar_message': {
        const { message, duration, color, background } =
          DisplayPolybarMessageSchema.parse(args);
        const result = await displayPolybarMessage(message, {
          duration: duration || 5,
          color: color || '#ffffff',
          background: background || '#333333',
        });
        return {
          content: [
            {
              type: 'text',
              text: `Polybar message displayed: "${message}"${result ? ` - ${result}` : ''}`,
            },
          ],
        };
      }

      case 'show_popup_notification': {
        const { title, message, urgency, timeout, icon } =
          ShowPopupNotificationSchema.parse(args);
        const result = await showPopupNotification(title, message, {
          urgency: urgency || 'normal',
          timeout: timeout || 5000,
          icon,
        });
        return {
          content: [
            {
              type: 'text',
              text: `Notification sent: "${title}" - "${message}"${result ? ` - ${result}` : ''}`,
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
  console.error('Polybar Notification MCP Server running on stdio');
}

main().catch((error) => {
  console.error('Fatal error in main():', error);
  process.exit(1);
});
