# Shared: list pending WeChat inbox items and format agent prompt
param(
  [string]$Inbox = $null
)

. "$PSScriptRoot\_weixin-paths.ps1"
if (-not $Inbox) { $Inbox = Get-WeixinInboxDir }

function Get-WeixinInboxPending {
  param([string]$InboxPath)
  if (-not (Test-Path $InboxPath)) { return @() }
  Get-ChildItem -Path $InboxPath -Filter "*.json" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '^(watch)' } |
    ForEach-Object {
      try {
        $o = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($o.status -eq "pending") {
          [PSCustomObject]@{ File = $_; Data = $o }
        }
      } catch {}
    }
}

function Format-WeixinInboxPrompt {
  param($Pending)
  $items = @()
  foreach ($entry in $Pending) {
    $d = $entry.Data
    $items += "file=$($entry.File.Name) user=$($d.from) context_token=$($d.context_token) text=$($d.text)"
  }
  $summary = $items -join " | "
  @"
[WeChat inbound — reply on WeChat in THIS session]
$summary
Use reply (preferred) or weixin_send with user + context_token + text. Keep replies concise. Do NOT poll.
After replying, set each inbox JSON status to "done" (same file path under .cursor/weixin-inbox/).
"@
}

$pending = @(Get-WeixinInboxPending -InboxPath $Inbox | Where-Object { $_ })
return @{
  Pending = $pending
  Prompt = if ($pending.Count -gt 0) { Format-WeixinInboxPrompt $pending } else { $null }
}
