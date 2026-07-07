# Build followup_message for pending inbox and/or dead wake loop
$ErrorActionPreference = "SilentlyContinue"
. "$PSScriptRoot\_weixin-paths.ps1"
$parts = @()

$pending = & "$PSScriptRoot\weixin-inbox-pending.ps1"
if ($pending.Pending -and $pending.Pending.Count -gt 0 -and $pending.Prompt) {
  $parts += $pending.Prompt
}

$status = & "$PSScriptRoot\weixin-inbox-wake-status.ps1"
if (-not $status.Alive) {
  if ($status.Pid) {
    Stop-Process -Id ([int]$status.Pid) -Force -ErrorAction SilentlyContinue
  }
  $parts += $status.RestartPrompt
}

if ($parts.Count -eq 0) {
  Write-Output '{}'
  exit 0
}

@{ followup_message = ($parts -join "`n`n") } | ConvertTo-Json -Compress | Write-Output
exit 0
