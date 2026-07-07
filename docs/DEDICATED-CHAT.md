# 独立 Chat / 独立窗口专管微信

截至 2026-07-07。与 OKX/ASP 等同工作区时，**一个 Cursor 窗口同一时刻只能跑一个 Agent 会话**。要微信和 OKX 真分开，用**第二个 Cursor 窗口 + 独立工作区 + 微信子 Agent**。

双子架构总览：[`../../docs/DESIGN-child-agents.md`](../../docs/DESIGN-child-agents.md)

## 推荐：cursor-weixin 专用窗口

### 1. 安装本仓库

```powershell
cd F:\AI\ai-write\cursor-weixin
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -WorkspaceRoot .
```

（加 `-WeixinOnlyHooks` 会写入仅微信的 `.cursor/hooks.json`。）

### 2. MCP 与 CLI

- `install.ps1` 复制 `examples/mcp.json` → `.cursor/mcp.json`（`${workspaceFolder}` 相对路径）
- `examples/cli.json` → `.cursor/cli.json`（**必须**为 `permissions` 结构；无效 schema 会导致 headless 子 Agent 启动失败）

### 3. 配置 Hooks（仅微信）

`.cursor/hooks.json` **不要**挂 ASP/OKX hooks。`sessionStart` 会：

- 调用 `ai-write/.cursor/hooks/agent-children-init.ps1` 确保微信子 chatId 存在
- 启动 `weixin-watch` + `wake-loop`

### 4. 新开 Cursor 窗口

**File → New Window → Open Folder → `F:\AI\ai-write\cursor-weixin`**

父 Chat 可统筹；**微信自动回复由子 Agent**（`agent-children.json` 里 `weixin` 的 chatId）处理，不污染本窗口父会话。

### 5. ai-write 窗口去掉微信（避免抢会话）

`F:\AI\ai-write\.cursor\hooks.json` 里**只保留** ASP hooks（`asp-watch-start`、`asp-attention-followup`、`asp-inbox-followup`），**不要**挂 `weixin-session-start` / `weixin-inbox-followup`。

### 6. inbox 与子 Agent

| 项 | 路径 / 行为 |
|----|-------------|
| inbox | `cursor-weixin/.cursor/weixin-inbox/` |
| 唤醒 | `wake-loop` 或 stop-hook → `Invoke-ChildAgentWake -Role weixin` |
| 回复 | 子 Agent 必须 MCP `reply`；Chat 正文不到微信 |
| 模型 | 跟随 CLI 全局默认，下次唤醒生效 |

**打开 Cursor 不会自动常驻子 Agent**；只有 inbox 出现 `pending` 才拉起。

## 不推荐：同一 ai-write 窗口开两个 Chat

- Hooks 是工作区级的，两个 Chat 共享
- 旧方案 `agent --continue` 无法指定「微信 Chat」
- 现已改用固定 `--resume` 子 chatId，但仍需 **cursor-weixin 专用窗口** 加载 weixin MCP

## 自检

```powershell
# 专用窗口内
Get-Content .cursor\weixin-inbox\wake-loop.pid          # 应有 pid
Get-Content ..\..\.cursor\agent-children.json           # weixin.chatId 存在
Get-Content ..\..\.cursor\child-wake-weixin.err.log -EA SilentlyContinue  # 无 cli.json schema 错误
```

发微信后：inbox 出现 `pending` JSON → 约数秒内子 Agent 回复 → `status=done`。

## 故障

| 现象 | 处理 |
|------|------|
| inbox 一直 pending | 查 `child-wake-weixin.err.log`；确认 `.cursor/cli.json` 为 permissions 结构 |
| 子 Agent 无 reply 工具 | 确认 `.cursor/mcp.json` 存在且 headless 带 `--approve-mcps` |
| wake-loop 不跑 | 专用窗口 sessionStart 未触发；手动 `weixin-wake-start.ps1` |
| 重复回复 | 两路同时唤醒；查 `child-wake-weixin.lock` |
