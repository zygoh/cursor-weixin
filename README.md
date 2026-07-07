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
| `examples/` | `hooks.json`、`mcp.json` 示例 |
| `install.ps1` | 一键安装到工作区 `.cursor/` |

## 安装

```powershell
git clone https://github.com/zygoh/cursor-weixin.git
cd your-workspace
powershell -NoProfile -ExecutionPolicy Bypass -File path\to\cursor-weixin\install.ps1
```

### 手动步骤

1. **微信登录**：`npx weixin-mcp login`（数据在 `%USERPROFILE%\.weixin-mcp`）
2. **MCP**：将 `examples/mcp.json` 合并进 Cursor MCP 配置
3. **Hooks**：将 `examples/hooks.json` 合并进 `.cursor/hooks.json`
4. **访问控制**：编辑 `%USERPROFILE%\.weixin-mcp\access.json` 的 `allowFrom`
5. **（推荐）** `.cursor/cli.json` 设 `approvalMode: unrestricted`，便于 wake-loop 自动放行

## 环境变量

| 变量 | 默认 | 说明 |
|------|------|------|
| `WEIXIN_MCP_DIR` | `%USERPROFILE%\.weixin-mcp` | weixin-mcp 数据目录 |
| `WEIXIN_INBOX_DIR` | `<workspace>/.cursor/weixin-inbox` | inbox JSON |
| `CURSOR_WEIXIN_WORKSPACE` | 自动推断 | 工作区根目录 |

## 注意

- 唤醒 Agent 必须用 **`agent.cmd`**，不要用 `agent.ps1`（否则 Windows 会用记事本打开）。
- wake-loop 每 20 分钟自旋退出，由 sessionStart / maintenance 重启。
- Chat 里打字不会发到微信；只有 MCP `reply` / `weixin_send` 会发。

## License

MIT
