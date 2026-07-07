function Get-WeixinWorkspaceRoot {
  if ($env:CURSOR_WEIXIN_WORKSPACE) {
    return (Resolve-Path $env:CURSOR_WEIXIN_WORKSPACE).Path
  }
  $fromHooks = Resolve-Path (Join-Path $PSScriptRoot "..\..") -ErrorAction SilentlyContinue
  if ($fromHooks -and (Test-Path (Join-Path $fromHooks.Path ".cursor"))) {
    return $fromHooks.Path
  }
  return (Get-Location).Path
}

function Get-WeixinInboxDir {
  param([string]$Root = (Get-WeixinWorkspaceRoot))
  Join-Path $Root ".cursor\weixin-inbox"
}

function Get-WeixinMcpDir {
  if ($env:WEIXIN_MCP_DIR) { return $env:WEIXIN_MCP_DIR }
  Join-Path $env:USERPROFILE ".weixin-mcp"
}
