# cursor-weixin

Cursor IDE 微信通道：通过 [weixin-mcp](https://www.npmjs.com/package/weixin-mcp) 收消息、MCP `reply` 回微信，配合 Cursor Hooks 实现 inbox 兜底与 `agent.cmd` 唤醒。

## 架构

```text
weixin-mcp (登录 + poll)
    ↓
weixin-channel MCP (index.mjs)  → claude/channel push → Cursor Agent
    ↓                              ↑
weixin-inbox/*.json  ← watch-loop / channel 双写
    ↓
wake-loop → agent.cmd --continue → Agent 用 reply 回微信
    ↓
stop hook → weixin-inbox-followup → followup_message 续跑
```

## 目录

| 路径 | 说明 |
|------|------|
| `channel/` | MCP Channel 服务（`index.mjs` + `package.json`） |
| `hooks/` | Cursor Hooks（sessionStart / stop / wake-loop） |
| `rules/weixin-mcp.mdc` | Agent 规则：必须用 `reply` 回微信 |
| `examples/` | `hooks.json`、`hooks.merge-ai-write.json`、`mcp.json` |
| `docs/DEDICATED-CHAT.md` | **独立窗口专管微信**（与 OKX 分开） |
| `install.ps1` | 一键安装到工作区 `.cursor/` |

## 安装到已有工作区（如 ai-write）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File F:\AI\cursor-weixin\install.ps1 -WorkspaceRoot F:\AI\ai-write
```

然后：

1. `npx weixin-mcp login`
2. 合并 `examples/mcp.json` 到 Cursor MCP 配置
3. 合并 `examples/hooks.merge-ai-write.json` 到 `.cursor/hooks.json`（或只用 `hooks.json` 做纯微信工作区）
4. （推荐）复制 `examples/cli.json` → `.cursor/cli.json`

## 独立 Chat 专管微信（与 OKX 分开）

见 **[docs/DEDICATED-CHAT.md](docs/DEDICATED-CHAT.md)**。

要点：**新开 Cursor 窗口，Open Folder 选本仓库**；ai-write 窗口去掉 weixin hooks。

## 环境变量

| 变量 | 默认 | 说明 |
|------|------|------|
| `WEIXIN_MCP_DIR` | `%USERPROFILE%\.weixin-mcp` | weixin-mcp 数据目录 |
| `WEIXIN_INBOX_DIR` | `<workspace>/.cursor/weixin-inbox` | inbox JSON（可指向共享路径） |
| `CURSOR_WEIXIN_WORKSPACE` | 自动推断 | Agent 工作区根（`agent --continue` 的 cwd） |

## 注意

- 唤醒必须用 **`agent.cmd`**，勿用 `agent.ps1`（否则会弹记事本）。
- Chat 里打字不会发到微信；只有 MCP `reply` / `weixin_send` 会发。
- wake-loop 常驻，不再 20 分钟自退。

## License

MIT
