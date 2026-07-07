# Build followup: 唤醒微信子 Agent（不污染当前父/窗口 Chat）
$ErrorActionPreference = "SilentlyContinue"
. "$PSScriptRoot\_weixin-paths.ps1"

$agentChild = Join-Path $PSScriptRoot "..\..\..\.cursor\hooks\agent-child.ps1"
if (Test-Path $agentChild) { . $agentChild }

$pending = & "$PSScriptRoot\weixin-inbox-pending.ps1"
if ($pending.Pending -and $pending.Pending.Count -gt 0 -and $pending.Prompt) {
  if (Get-Command Invoke-ChildAgentWake -ErrorAction SilentlyContinue) {
    Invoke-ChildAgentWake -Role weixin -TaskPrompt $pending.Prompt | Out-Null
  }
}

$status = & "$PSScriptRoot\weixin-inbox-wake-status.ps1"
if (-not $status.Alive) {
  if ($status.Pid) {
    Stop-Process -Id ([int]$status.Pid) -Force -ErrorAction SilentlyContinue
  }
  & "$PSScriptRoot\weixin-wake-start.ps1"
}

Write-Output '{}'
exit 0
