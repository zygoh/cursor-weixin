# sessionStart: child chats + watch + wake loops
$ErrorActionPreference = "SilentlyContinue"
. "$PSScriptRoot\_weixin-paths.ps1"
$init = Join-Path $PSScriptRoot "..\..\..\.cursor\hooks\agent-children-init.ps1"
if (Test-Path $init) { & $init | Out-Null }
& "$PSScriptRoot\weixin-watch-start.ps1"
& "$PSScriptRoot\weixin-wake-start.ps1"
& "$PSScriptRoot\weixin-inbox-followup.ps1"
