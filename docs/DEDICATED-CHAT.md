# 独立 Chat / 独立窗口专管微信

与 OKX/ASP 等同工作区时，**一个 Cursor 窗口同一时刻只能跑一个 Agent 会话**。要微信和 OKX 真分开，用**第二个 Cursor 窗口 + 独立工作区**。

## 推荐：cursor-weixin 专用窗口

### 1. 安装本仓库

```powershell
cd F:\AI\cursor-weixin
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -WorkspaceRoot .
```

### 2. 配置 MCP

把 `examples/mcp.json` 合并进 Cursor MCP（用户级或项目级），确保 **weixin** 服务器指向本工作区的 `channel/index.mjs`。

### 3. 配置 Hooks（仅微信）

复制 `examples/hooks.json` 为 `.cursor/hooks.json`（**不要**挂 ASP/OKX hooks）。

### 4. 新开 Cursor 窗口

**File → New Window → Open Folder → `F:\AI\cursor-weixin`**

在此窗口新建 Chat，首条可写：

> 你是微信专管 Agent。收到微信消息必须用 reply 回微信，不要处理 OKX/ASP。

### 5. ai-write 窗口去掉微信（避免抢会话）

在 `F:\AI\ai-write\.cursor\hooks.json` 里**删除** `weixin-session-start` 与 `weixin-inbox-followup`，只保留 ASP hooks。

### 6.（可选）共用 inbox

若希望 poll 写入与 ai-write 同一目录：

```powershell
# 系统环境变量或 cursor-weixin 窗口的 MCP env
WEIXIN_INBOX_DIR=F:\AI\ai-write\.cursor\weixin-inbox
```

专用窗口的 wake-loop 会读同一 inbox，`agent --continue` 只续 **cursor-weixin 窗口**里的 Chat，不再和 OKX 抢。

## 不推荐：同一 ai-write 窗口开两个 Chat

- Hooks 是工作区级的，两个 Chat 共享
- `agent --continue` 只续**该工作区最近一次** Agent 会话，无法指定「微信 Chat」
- 只适合你在微信 Chat 里手动挂着，不适合后台自动回复

## 自检

```powershell
# 专用窗口内
Get-Content .cursor\weixin-inbox\wake-loop.pid
# 应有进程；发微信后 inbox 出现 pending JSON，几秒内应 reply
```
