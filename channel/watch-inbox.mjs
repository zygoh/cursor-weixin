#!/usr/bin/env node
/** Background poll → weixin-inbox JSON (no CLI text parsing). */
import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { randomBytes } from "node:crypto";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const INBOX_DIR =
  process.env.WEIXIN_INBOX_DIR ?? path.join(__dirname, "..", "weixin-inbox");
const LOG_FILE = path.join(INBOX_DIR, "watch.log");
const POLL_MS = 8000;

const require = createRequire(import.meta.url);
const weixinRoot = path.dirname(require.resolve("weixin-mcp/package.json"));
const importWeixin = (rel) => import(pathToFileURL(path.join(weixinRoot, rel)).href);
const {
  DEFAULT_BASE_URL,
  getUpdates,
  loadCursor,
  saveCursor,
} = await importWeixin("dist/api.js");
const { ACCOUNTS_DIR } = await importWeixin("dist/paths.js");
const { updateContactsFromMsgs, loadContacts } = await importWeixin(
  "dist/contacts.js"
);

function log(msg) {
  fs.mkdirSync(INBOX_DIR, { recursive: true });
  fs.appendFileSync(LOG_FILE, `${new Date().toISOString()} ${msg}\n`);
}

function loadAccount() {
  const files = fs
    .readdirSync(ACCOUNTS_DIR)
    .filter(
      (f) =>
        f.endsWith(".json") &&
        !f.endsWith(".sync.json") &&
        !f.endsWith(".cursor.json")
    );
  if (!files.length) throw new Error("No WeChat account. Run: npx weixin-mcp login");
  const accountId =
    process.env.WEIXIN_ACCOUNT_ID ?? files[0].replace(".json", "");
  const data = JSON.parse(
    fs.readFileSync(path.join(ACCOUNTS_DIR, `${accountId}.json`), "utf-8")
  );
  if (!data.token) throw new Error(`No token for ${accountId}`);
  return { ...data, accountId };
}

function loadAccess() {
  try {
    return JSON.parse(
      fs.readFileSync(path.join(path.dirname(ACCOUNTS_DIR), "access.json"), "utf-8")
    );
  } catch {
    return { dmPolicy: "contacts", allowFrom: [] };
  }
}

function isAllowed(userId, access) {
  if (!userId || userId.includes("@im.bot")) return false;
  if (access.allowFrom?.includes(userId)) return true;
  if (access.dmPolicy === "disabled") return false;
  if (access.allowFrom?.length > 0) return false;
  return Boolean(loadContacts()[userId]);
}

function extractText(msg) {
  const item = msg.item_list?.find((i) => i.type === 1);
  return item?.text_item?.text?.trim() ?? "";
}

function writeInbox(from, text, contextToken) {
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
  log(`inbox ${id} from=${from} text=${text}`);
  return id;
}

async function pollOnce() {
  const account = loadAccount();
  const { token, baseUrl = DEFAULT_BASE_URL, accountId } = account;
  const cursor = loadCursor(accountId);
  const resp = await getUpdates(token, baseUrl, cursor);
  if (resp.get_updates_buf) saveCursor(accountId, resp.get_updates_buf);
  if (!resp.msgs?.length) return;
  updateContactsFromMsgs(resp.msgs);
  const access = loadAccess();
  for (const msg of resp.msgs) {
    const from = String(msg.from_user_id ?? "");
    if (!isAllowed(from, access)) {
      log(`blocked from=${from}`);
      continue;
    }
    const text = extractText(msg);
    if (!text) continue;
    writeInbox(from, text, String(msg.context_token ?? ""));
  }
}

log("watch-inbox started");
while (true) {
  try {
    await pollOnce();
  } catch (err) {
    log(`poll error: ${err?.message ?? err}`);
    await new Promise((r) => setTimeout(r, 5000));
  }
  await new Promise((r) => setTimeout(r, POLL_MS));
}
