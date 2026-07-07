# Install cursor-weixin into a Cursor workspace
param(
  [string]$WorkspaceRoot = (Get-Location).Path,
  [switch]$WeixinOnlyHooks
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$cursorDir = Join-Path $WorkspaceRoot ".cursor"

New-Item -ItemType Directory -Force -Path (Join-Path $cursorDir "hooks") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $cursorDir "rules") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $cursorDir "weixin-inbox") | Out-Null

Copy-Item (Join-Path $RepoRoot "hooks\*.ps1") (Join-Path $cursorDir "hooks\") -Force
Copy-Item (Join-Path $RepoRoot "rules\weixin-mcp.mdc") (Join-Path $cursorDir "rules\") -Force

$channelDst = Join-Path $cursorDir "weixin-channel"
if (Test-Path $channelDst) { Remove-Item $channelDst -Recurse -Force }
Copy-Item (Join-Path $RepoRoot "channel") $channelDst -Recurse -Force
if (Test-Path (Join-Path $channelDst "node_modules")) {
  Remove-Item (Join-Path $channelDst "node_modules") -Recurse -Force
}

Push-Location $channelDst
npm install --omit=dev
Pop-Location

$hooksExample = if ($WeixinOnlyHooks) {
  Join-Path $RepoRoot "examples\hooks.json"
} else {
  $null
}
if ($WeixinOnlyHooks -and (Test-Path $hooksExample)) {
  Copy-Item $hooksExample (Join-Path $cursorDir "hooks.json") -Force
}

$cliExample = Join-Path $RepoRoot "examples\cli.json"
if (-not (Test-Path (Join-Path $cursorDir "cli.json")) -and (Test-Path $cliExample)) {
  Copy-Item $cliExample (Join-Path $cursorDir "cli.json")
}

$mcpPath = Join-Path $cursorDir "mcp.json"
$wsAbs = (Resolve-Path $WorkspaceRoot).Path -replace '\\', '/'
$inboxAbs = (Join-Path $cursorDir "weixin-inbox") -replace '\\', '/'
$mcpDirAbs = (Join-Path $env:USERPROFILE ".weixin-mcp") -replace '\\', '/'
$channelIndex = (Join-Path $channelDst "index.mjs") -replace '\\', '/'
@{
  mcpServers = @{
    weixin = @{
      command = "node"
      args    = @($channelIndex)
      env     = @{
        WEIXIN_MCP_DIR   = $mcpDirAbs
        WEIXIN_INBOX_DIR = $inboxAbs
      }
    }
  }
} | ConvertTo-Json -Depth 5 | Set-Content -Path $mcpPath -Encoding UTF8

Write-Host "Installed to $cursorDir"
Write-Host "Next:"
Write-Host "  1. npx weixin-mcp login"
Write-Host "  2. .cursor/mcp.json written with absolute paths (required for headless agent.cmd)"
if (-not $WeixinOnlyHooks) {
  Write-Host "  3. Merge examples/hooks.merge-ai-write.json (or hooks.json) into .cursor/hooks.json"
} else {
  Write-Host "  3. hooks.json written (weixin-only). Open this folder in a NEW Cursor window."
}
Write-Host "  4. Dedicated weixin chat: docs/DEDICATED-CHAT.md"
