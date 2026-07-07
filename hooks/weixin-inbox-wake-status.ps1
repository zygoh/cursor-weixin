# Check weixin inbox wake loop health (process + heartbeat)
param(
  [string]$Inbox = $null
)

. "$PSScriptRoot\_weixin-paths.ps1"
if (-not $Inbox) { $Inbox = Get-WeixinInboxDir }

$wakeScript = Join-Path $PSScriptRoot "weixin-inbox-wake-loop.ps1"
$pidFile = Join-Path $Inbox "wake-loop.pid"
$heartbeatFile = Join-Path $Inbox "wake-loop.heartbeat"
$alive = $false
$wakePid = $null

if (Test-Path $pidFile) {
  $wakePid = (Get-Content $pidFile -Raw).Trim()
  if ($wakePid -and (Get-Process -Id ([int]$wakePid) -ErrorAction SilentlyContinue)) {
    if (Test-Path $heartbeatFile) {
      try {
        $last = [datetime](Get-Content $heartbeatFile -Raw)
        if (((Get-Date) - $last).TotalSeconds -lt 30) { $alive = $true }
      } catch {}
    }
  }
}

return @{
  Alive = $alive
  Pid = $wakePid
  RestartPrompt = @"
[Weixin maintenance] Restart inbox wake loop in a monitored background shell:
powershell -NoProfile -ExecutionPolicy Bypass -File $wakeScript
Use notify_on_output pattern ^AGENT_LOOP_WAKE_WEIXIN. Kill stale wake-loop.pid process first if needed. Then process any pending weixin-inbox messages.
"@
}
