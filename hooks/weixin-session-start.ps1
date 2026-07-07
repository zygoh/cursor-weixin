# sessionStart: ensure watch + wake loops, then followup for pending inbox
$ErrorActionPreference = "SilentlyContinue"
. "$PSScriptRoot\_weixin-paths.ps1"
& "$PSScriptRoot\weixin-watch-start.ps1"
& "$PSScriptRoot\weixin-wake-start.ps1"
& "$PSScriptRoot\weixin-inbox-followup.ps1"
