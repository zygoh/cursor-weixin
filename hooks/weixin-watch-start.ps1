# 后台监听微信消息，写入 inbox 供 stop hook / Agent 读取
$ErrorActionPreference = "SilentlyContinue"
. "$PSScriptRoot\_weixin-paths.ps1"
$mcpDir = Get-WeixinMcpDir
$inbox = Get-WeixinInboxDir
$workspace = Get-WeixinWorkspaceRoot
$pidFile = Join-Path $inbox "watch.pid"
$logFile = Join-Path $inbox "watch.log"
$watchMjs = Join-Path $workspace ".cursor\weixin-channel\watch-inbox.mjs"
$srcMjs = Join-Path $workspace "channel\watch-inbox.mjs"

$env:WEIXIN_MCP_DIR = $mcpDir
$env:WEIXIN_INBOX_DIR = $inbox
New-Item -ItemType Directory -Force -Path $inbox | Out-Null

if (Test-Path $pidFile) {
  $oldPid = (Get-Content $pidFile -Raw).Trim()
  if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
    exit 0
  }
}

if (-not (Test-Path $watchMjs) -and (Test-Path $srcMjs)) {
  Copy-Item $srcMjs $watchMjs -Force
}

if (-not (Test-Path $watchMjs)) {
  Add-Content -Path $logFile -Value "$(Get-Date -Format o) watch-inbox.mjs missing"
  exit 1
}

$proc = Start-Process -FilePath "node" `
  -ArgumentList $watchMjs `
  -WorkingDirectory (Split-Path $watchMjs) `
  -PassThru -WindowStyle Hidden

Set-Content -Path $pidFile -Value $proc.Id -Encoding ASCII
Add-Content -Path $logFile -Value "$(Get-Date -Format o) started watch node pid=$($proc.Id)"
