# cursor-weixin

Cursor IDE 微信通道：通过 [weixin-mcp](https://www.npmjs.com/package/weixin-mcp) 收消息、MCP `reply` 回微信，配合 Cursor Hooks 与 **微信子 Agent**（`--resume` 固定 chatId）实现后台自动回复，**不污染** ai-write 父 Chat。

人类说明（与 OKX 双子架构）：[`../docs/DESIGN-child-agents.md`](../docs/DESIGN-child-agents.md)

## 架构

```text
weixin-mcp (登录 + poll)
    ↓
weixin-channel MCP (index.mjs)  → claude/channel push（窗口开着时）
    ↓
weixin-inbox/*.json  ← watch-loop / channel 双写
    ↓
wake-loop / stop-hook → Invoke-ChildAgentWake (weixin)
    → agent --resume <weixin-chatId> --approve-mcps ...
    → 微信子 Agent 用 reply 回微信 → inbox 标 done
```

**子 Agent 非常驻**：sessionStart 只起 `weixin-watch` + `wake-loop`；有 pending 消息才 headless 拉起子 Agent。

## 目录

| 路径 | 说明 |
|------|------|
| `channel/` | MCP Channel 源码（`install.ps1` 复制到 `.cursor/weixin-channel/`） |
| `hooks/` | Cursor Hooks 源文件（安装到 `.cursor/hooks/`） |
| `rules/weixin-mcp.mdc` | Agent 规则：必须用 `reply` 回微信 |
| `examples/` | `hooks.json`、`mcp.json`、`cli.json` 模板 |
| `docs/DEDICATED-CHAT.md` | **独立窗口专管微信**（与 OKX 分开） |
| `install.ps1` | 一键安装到工作区 `.cursor/` |

## 安装（本仓库作专用窗口）

```powershell
cd F:\AI\ai-write\cursor-weixin
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -WorkspaceRoot . -WeixinOnlyHooks
```

然后：

1. `npx weixin-mcp login`
2. **File → New Window → Open Folder → 本目录**
3. 新开 Chat（可选：声明「微信专管，用 reply 回微信」）

`install.ps1` 会复制 `examples/mcp.json` → `.cursor/mcp.json`、`examples/cli.json` → `.cursor/cli.json`（若不存在）。

## 与 ai-write 双子架构

| 组件 | 位置 |
|------|------|
| 子 Agent 注册表 | `ai-write/.cursor/agent-children.json` |
| 唤醒逻辑 | `ai-write/.cursor/hooks/agent-child.ps1` |
| 微信 inbox | `cursor-weixin/.cursor/weixin-inbox/` |
| ai-write hooks | **仅** ASP（勿挂 weixin hooks） |

要点：**新开 Cursor 窗口 Open 本仓库**；父窗口统筹 OKX，微信走子 Agent。

## 环境变量

| 变量 | 默认 | 说明 |
|------|------|------|
| `WEIXIN_MCP_DIR` | `%USERPROFILE%\.weixin-mcp` | weixin-mcp 数据目录 |
| `WEIXIN_INBOX_DIR` | `<workspace>/.cursor/weixin-inbox` | inbox JSON |
| `CURSOR_WEIXIN_WORKSPACE` | 自动推断 | headless 唤醒的 cwd |

## 模型

子 Agent **不单独固定模型**；每次唤醒用 CLI 全局默认（`~/.cursor/cli-config.json`）。换模型后**下次唤醒**生效。

## 注意

- 唤醒必须用 **`agent.cmd`**，勿用 `agent.ps1`（否则会弹记事本）。
- Chat 里打字不会发到微信；只有 MCP `reply` / `weixin_send` 会发。
- headless 唤醒须 `.cursor/cli.json` 为合法 `permissions` 结构（勿用无效 `approvalMode` 单字段）。
- wake-loop 常驻；唤醒失败的消息下轮重试（不标 notified）。
- 诊断：`.cursor/child-wake-weixin.out.log` / `.err.log`（在 ai-write 根 `.cursor/`）。

## License

MIT
