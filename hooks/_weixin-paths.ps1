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
  if ($env:WEIXIN_INBOX_DIR) { return $env:WEIXIN_INBOX_DIR }
  Join-Path $Root ".cursor\weixin-inbox"
}

function Get-WeixinMcpDir {
  if ($env:WEIXIN_MCP_DIR) { return $env:WEIXIN_MCP_DIR }
  Join-Path $env:USERPROFILE ".weixin-mcp"
}

function Get-WeixinContactsPath {
  $mcpDir = Get-WeixinMcpDir
  foreach ($p in @(
    (Join-Path $mcpDir "contacts.json"),
    (Join-Path $env:USERPROFILE "contacts.json"),
    (Join-Path $env:USERPROFILE ".weixin-mcp\contacts.json")
  )) {
    if (Test-Path $p) { return $p }
  }
  return $null
}

function Resolve-WeixinPollSender {
  param([string]$ShortId)
  $result = @{ UserId = $ShortId; ContextToken = $null }
  $path = Get-WeixinContactsPath
  if (-not $path) { return $result }
  try {
    $raw = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($prop in $raw.PSObject.Properties) {
      $id = $prop.Name
      if ($id -eq $ShortId -or $id.StartsWith($ShortId)) {
        return @{ UserId = $id; ContextToken = $prop.Value.contextToken }
      }
    }
  } catch {}
  return $result
}
