# 后台监听微信消息，写入 inbox 供 stop hook / Agent 读取
$ErrorActionPreference = "SilentlyContinue"
. "$PSScriptRoot\_weixin-paths.ps1"
$mcpDir = Get-WeixinMcpDir
$inbox = Get-WeixinInboxDir
$pidFile = Join-Path $inbox "watch.pid"
$logFile = Join-Path $inbox "watch.log"

$env:WEIXIN_MCP_DIR = $mcpDir
New-Item -ItemType Directory -Force -Path $inbox | Out-Null

if (Test-Path $pidFile) {
  $oldPid = Get-Content $pidFile -Raw
  if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
    exit 0
  }
}

$pollScript = @"
. '$($PSScriptRoot -replace "'", "''")\_weixin-paths.ps1'
`$env:WEIXIN_MCP_DIR = '$($mcpDir -replace "'", "''")'
`$inbox = '$(($inbox) -replace "'", "''")'
while (`$true) {
  try {
    `$out = & npx -y weixin-mcp poll 2>&1 | Out-String
    if (`$out -match 'message\(s\)' -and `$out -notmatch 'No new messages') {
      `$lines = (`$out -split "`n") | Where-Object { `$_ -match '^\s*←\s' }
      foreach (`$line in `$lines) {
        if (`$line -match '←\s([^:]+):\s*(.+)') {
          `$from = `$Matches[1].Trim()
          `$text = `$Matches[2].Trim()
          `$id = [guid]::NewGuid().ToString("n").Substring(0, 12)
          `$payload = @{
            id = `$id
            status = "pending"
            from = `$from
            text = `$text
            received_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
          }
          `$path = Join-Path `$inbox "`$id.json"
          `$payload | ConvertTo-Json -Compress | Set-Content -Path `$path -Encoding UTF8
          Add-Content -Path (Join-Path `$inbox "watch.log") -Value "`$(Get-Date -Format o) inbox `$id from=`$from text=`$text"
        }
      }
    }
  } catch {}
  Start-Sleep -Seconds 8
}
"@

$pollScriptPath = Join-Path $inbox "watch-loop.ps1"
Set-Content -Path $pollScriptPath -Value $pollScript -Encoding UTF8

$proc = Start-Process -FilePath "powershell.exe" `
  -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-File",$pollScriptPath `
  -PassThru -WindowStyle Hidden

Set-Content -Path $pidFile -Value $proc.Id -Encoding ASCII
Add-Content -Path $logFile -Value "$(Get-Date -Format o) started watch pid=$($proc.Id)"
