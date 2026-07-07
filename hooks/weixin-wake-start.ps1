# sessionStart: ensure weixin inbox wake loop is running (restart if dead)
$ErrorActionPreference = "SilentlyContinue"
. "$PSScriptRoot\_weixin-paths.ps1"
$inbox = Get-WeixinInboxDir
$pidFile = Join-Path $inbox "wake-loop.pid"
$logFile = Join-Path $inbox "wake-loop.log"
$wakeScript = Join-Path $PSScriptRoot "weixin-inbox-wake-loop.ps1"

New-Item -ItemType Directory -Force -Path $inbox | Out-Null

$status = & "$PSScriptRoot\weixin-inbox-wake-status.ps1" -Inbox $inbox
if ($status.Alive) { exit 0 }

if ($status.Pid) {
  Stop-Process -Id ([int]$status.Pid) -Force -ErrorAction SilentlyContinue
}

$proc = Start-Process -FilePath "powershell.exe" `
  -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", $wakeScript `
  -PassThru -WindowStyle Hidden

Set-Content -Path $pidFile -Value $proc.Id -Encoding ASCII
Add-Content -Path $logFile -Value "$(Get-Date -Format o) started wake-loop pid=$($proc.Id)"
