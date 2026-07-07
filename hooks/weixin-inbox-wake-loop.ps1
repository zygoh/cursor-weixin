# Background loop: wake Cursor agent when weixin-inbox has pending messages
$ErrorActionPreference = "SilentlyContinue"
. "$PSScriptRoot\_weixin-paths.ps1"
$inbox = Get-WeixinInboxDir
$workspace = Get-WeixinWorkspaceRoot
$pidFile = Join-Path $inbox "wake-loop.pid"
$heartbeatFile = Join-Path $inbox "wake-loop.heartbeat"
$notified = @{}
$logFile = Join-Path $inbox "wake-loop.log"

function Get-AgentCommand {
  $cmdShim = Join-Path $env:LOCALAPPDATA "cursor-agent\agent.cmd"
  if (Test-Path $cmdShim) { return $cmdShim }
  $cmd = Get-Command agent.cmd -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Invoke-AgentWake {
  param([string]$Prompt)
  $agent = Get-AgentCommand
  if (-not $agent) { return $false }
  Start-Process -FilePath $agent -ArgumentList @(
    "--continue", "--trust", "-p", $Prompt, "--force"
  ) -WorkingDirectory $workspace -WindowStyle Hidden | Out-Null
  return $true
}

New-Item -ItemType Directory -Force -Path $inbox | Out-Null
Set-Content -Path $pidFile -Value $PID -Encoding ASCII

try {
  $started = Get-Date
  while ($true) {
    Set-Content -Path $heartbeatFile -Value (Get-Date -Format o) -Encoding UTF8

    # Rotate every 20 min so stop/session hooks re-bind a fresh monitored shell
    if (((Get-Date) - $started).TotalMinutes -ge 20) { break }

    $result = & "$PSScriptRoot\weixin-inbox-pending.ps1" -Inbox $inbox
    $newPending = @()
    foreach ($entry in $result.Pending) {
      $id = $entry.Data.id
      if ($id -and -not $notified.ContainsKey($id)) {
        $newPending += $entry
        $notified[$id] = $true
      }
    }

    foreach ($id in @($notified.Keys)) {
      $path = Join-Path $inbox "$id.json"
      if (-not (Test-Path $path)) {
        $notified.Remove($id) | Out-Null
        continue
      }
      try {
        $o = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($o.status -ne "pending") { $notified.Remove($id) | Out-Null }
      } catch {
        $notified.Remove($id) | Out-Null
      }
    }

    if ($newPending.Count -gt 0) {
      $items = @()
      foreach ($entry in $newPending) {
        $d = $entry.Data
        $items += "file=$($entry.File.Name) user=$($d.from) context_token=$($d.context_token) text=$($d.text)"
      }
      $summary = $items -join " | "
      $prompt = @"
[WeChat inbound — reply on WeChat in THIS session]
$summary
Use reply (preferred) or weixin_send with user + context_token + text. Keep replies concise. Do NOT poll.
After replying, set each inbox JSON status to "done".
"@
      $payload = @{ prompt = $prompt } | ConvertTo-Json -Compress
      Write-Output "AGENT_LOOP_WAKE_WEIXIN $payload"
      if (Invoke-AgentWake -Prompt $prompt) {
        Add-Content -Path $logFile -Value "$(Get-Date -Format o) agent-wake pending=$($newPending.Count)"
      }
    }

    Start-Sleep -Seconds 5
  }
} finally {
  Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
  Remove-Item $heartbeatFile -Force -ErrorAction SilentlyContinue
}
