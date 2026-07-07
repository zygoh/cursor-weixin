#!/usr/bin/env node
/**
 * WeChat Channel MCP — background poll + claude/channel push into Cursor Agent session.
 * Reply via `reply` tool (WeChat). Requires Cursor open with this MCP loaded.
 */
import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { randomBytes } from "node:crypto";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const INBOX_DIR =
  process.env.WEIXIN_INBOX_DIR ?? path.join(__dirname, "..", "weixin-inbox");
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const require = createRequire(import.meta.url);
const weixinRoot = path.dirname(require.resolve("weixin-mcp/package.json"));
const importWeixin = (rel) => import(pathToFileURL(path.join(weixinRoot, rel)).href);
const {
  DEFAULT_BASE_URL,
  getUpdates,
  sendTextMessage,
  loadCursor,
  saveCursor,
} = await importWeixin("dist/api.js");
const { ACCOUNTS_DIR } = await importWeixin("dist/paths.js");
const { loadContacts, updateContactsFromMsgs } = await importWeixin(
  "dist/contacts.js"
);

const CHANNEL_INSTRUCTIONS = `The sender reads WeChat, not this session. Anything you want them to see must go through the reply tool — your transcript output never reaches their chat.

Messages from WeChat arrive as <channel source="weixin" user="..." context_token="..." ts="...">. Reply with the reply tool — pass user (WeChat userId) and context_token from the inbound tag. Keep replies concise and helpful.

Do NOT call weixin_poll when a channel message is already in context — the content is above.`;

function loadAccount() {
  const dir = ACCOUNTS_DIR;
  const files = fs
    .readdirSync(dir)
    .filter(
      (f) =>
        f.endsWith(".json") &&
        !f.endsWith(".sync.json") &&
        !f.endsWith(".cursor.json")
    );
  if (files.length === 0) {
    throw new Error("No WeChat account. Run: npx weixin-mcp login");
  }
  const accountId =
    process.env.WEIXIN_ACCOUNT_ID ?? files[0].replace(".json", "");
  const data = JSON.parse(
    fs.readFileSync(path.join(dir, `${accountId}.json`), "utf-8")
  );
  if (!data.token) {
    throw new Error(`No token for ${accountId}. Run: npx weixin-mcp login`);
  }
  return { ...data, accountId };
}

function accessPath() {
  return path.join(path.dirname(ACCOUNTS_DIR), "access.json");
}

function loadAccess() {
  try {
    return JSON.parse(fs.readFileSync(accessPath(), "utf-8"));
  } catch {
    return { dmPolicy: "contacts", allowFrom: [] };
  }
}

function isAllowed(userId, access) {
  if (!userId || userId.includes("@im.bot")) return false;
  if (access.allowFrom?.includes(userId)) return true;
  if (access.dmPolicy === "disabled") return false;
  if (access.allowFrom?.length > 0) return false;
  // Default: allow known contacts (users who have messaged the bot before)
  return Boolean(loadContacts()[userId]);
}

function extractText(msg) {
  const item = msg.item_list?.find((i) => i.type === 1);
  return item?.text_item?.text?.trim() ?? "";
}

function resolveUserId(input) {
  if (!input || input.includes("@")) return input;
  const contacts = loadContacts();
  const matches = Object.keys(contacts).filter(
    (id) => id.startsWith(input) || id.includes(input)
  );
  return matches.length === 1 ? matches[0] : input;
}

const server = new Server(
  { name: "weixin-channel", version: "0.1.0" },
  {
    capabilities: {
      tools: {},
      experimental: { "claude/channel": {} },
    },
    instructions: CHANNEL_INSTRUCTIONS,
  }
);

let pollRunning = false;

function writeInbox(from, text, contextToken) {
  fs.mkdirSync(INBOX_DIR, { recursive: true });
  const id = randomBytes(6).toString("hex");
  const payload = {
    id,
    status: "pending",
    from,
    text,
    context_token: contextToken,
    received_at: new Date().toISOString(),
  };
  fs.writeFileSync(
    path.join(INBOX_DIR, `${id}.json`),
    JSON.stringify(payload),
    "utf-8"
  );
  console.error(`[weixin-channel] inbox ${id} from=${from} text=${text}`);
  return id;
}

async function pushInboundMessage(msg) {
  const from = String(msg.from_user_id ?? "");
  const access = loadAccess();
  if (!isAllowed(from, access)) {
    console.error(`[weixin-channel] blocked from=${from}`);
    return;
  }

  const text = extractText(msg);
  if (!text) return;

  const contextToken = String(msg.context_token ?? "");
  writeInbox(from, text, contextToken);

  try {
    await server.notification({
      method: "notifications/claude/channel",
      params: {
        content: text,
        meta: {
          source: "weixin",
          user: from,
          context_token: contextToken,
          ts: new Date().toISOString(),
        },
      },
    });
    console.error(`[weixin-channel] channel push ok from=${from}`);
  } catch (err) {
    console.error(
      `[weixin-channel] channel push failed: ${err?.message ?? err}`
    );
  }
}

async function pollOnce() {
  const account = loadAccount();
  const { token, baseUrl = DEFAULT_BASE_URL, accountId } = account;
  const cursor = loadCursor(accountId);
  const resp = await getUpdates(token, baseUrl, cursor);
  if (resp.get_updates_buf) saveCursor(accountId, resp.get_updates_buf);
  if (!resp.msgs?.length) return;
  updateContactsFromMsgs(resp.msgs);
  for (const msg of resp.msgs) {
    await pushInboundMessage(msg);
  }
}

function startBackgroundPoll() {
  if (pollRunning) return;
  pollRunning = true;
  (async () => {
    console.error("[weixin-channel] background poll started");
    while (pollRunning) {
      try {
        await pollOnce();
      } catch (err) {
        console.error("[weixin-channel] poll error:", err?.message ?? err);
        await new Promise((r) => setTimeout(r, 5000));
      }
    }
  })();
}

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "reply",
      description:
        "Reply on WeChat. Pass user and context_token from the inbound <channel> tag.",
      inputSchema: {
        type: "object",
        properties: {
          user: { type: "string", description: "WeChat userId from channel meta" },
          text: { type: "string", description: "Reply text" },
          context_token: {
            type: "string",
            description: "context_token from channel meta (keeps thread)",
          },
        },
        required: ["user", "text"],
      },
    },
    {
      name: "weixin_send",
      description: "Send WeChat text (alias). Prefer reply when responding to channel.",
      inputSchema: {
        type: "object",
        properties: {
          to: { type: "string" },
          text: { type: "string" },
          context_token: { type: "string" },
        },
        required: ["to", "text"],
      },
    },
    {
      name: "weixin_contacts",
      description: "List WeChat contacts who messaged the bot.",
      inputSchema: { type: "object", properties: {} },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const account = loadAccount();
  const { token, baseUrl = DEFAULT_BASE_URL } = account;
  const { name, arguments: args } = req.params;

  try {
    if (name === "reply" || name === "weixin_send") {
      const to = resolveUserId(String(args?.user ?? args?.to ?? ""));
      const text = String(args?.text ?? "").trim();
      const context_token = args?.context_token
        ? String(args.context_token)
        : undefined;
      if (!to || !text) throw new Error("user/to and text are required");
      const result = await sendTextMessage(
        to,
        text,
        token,
        baseUrl,
        context_token
      );
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    }
    if (name === "weixin_contacts") {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(Object.values(loadContacts()), null, 2),
          },
        ],
      };
    }
    throw new Error(`Unknown tool: ${name}`);
  } catch (err) {
    return {
      content: [{ type: "text", text: `Error: ${err.message ?? err}` }],
      isError: true,
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
startBackgroundPoll();
console.error("[weixin-channel] MCP channel server running on stdio");
