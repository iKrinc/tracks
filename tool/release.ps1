# Publishes dist\tracks.apk and dist\tracks-universal.apk as a GitHub
# release, using the GitHub login Git already stores (Git Credential
# Manager). The token stays in memory and is never printed.
# Usage: .\tool\release.ps1 -Tag v0.2.0
param([Parameter(Mandatory)] [string] $Tag, [string] $Repo = 'iKrinc/tracks')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

$cred = "protocol=https`nhost=github.com`n`n" | git credential fill
$token = ($cred | Where-Object { $_ -like 'password=*' }) -replace '^password=', ''
if (-not $token) { throw 'No GitHub login stored; run git push once first.' }
$h = @{
  Authorization          = "Bearer $token"
  Accept                 = 'application/vnd.github+json'
  'X-GitHub-Api-Version' = '2022-11-28'
}

$version = (Select-String -Path "$root\pubspec.yaml" -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$notes = @"
Tracks $version for Android. Not on the Play Store: download, open the file, and allow this one install when Android asks.

- **tracks.apk**: most phones (64-bit, Android 7+)
- **tracks-universal.apk**: every phone, larger

Signed with the Tracks key, certificate SHA-256 ca7143b8e365a457ffda4183684814c4601a39908ac028497c0b83540fee7cba.
"@

$existing = $null
try { $existing = Invoke-RestMethod -Headers $h "https://api.github.com/repos/$Repo/releases/tags/$Tag" } catch {}
if ($existing) {
  $rel = $existing
} else {
  $body = @{ tag_name = $Tag; target_commitish = 'main'; name = "Tracks $version"; body = $notes; make_latest = 'true' } | ConvertTo-Json
  $rel = Invoke-RestMethod -Method Post -Headers $h -ContentType 'application/json' -Body $body "https://api.github.com/repos/$Repo/releases"
}

foreach ($name in 'tracks.apk', 'tracks-universal.apk') {
  foreach ($a in $rel.assets | Where-Object { $_.name -eq $name }) {
    Invoke-RestMethod -Method Delete -Headers $h "https://api.github.com/repos/$Repo/releases/assets/$($a.id)" | Out-Null
  }
  $file = Join-Path $root "dist\$name"
  $up = "https://uploads.github.com/repos/$Repo/releases/$($rel.id)/assets?name=$name"
  $asset = Invoke-RestMethod -Method Post -Headers $h -ContentType 'application/vnd.android.package-archive' -InFile $file $up
  "$name uploaded: $([math]::Round($asset.size / 1MB, 1)) MB"
}
"Release: $($rel.html_url)"
