$ErrorActionPreference = "Stop"

$root   = Split-Path -Parent $PSScriptRoot
$pandoc = "$root\pandoc\pandoc-3.6.4\pandoc.exe"
$posts  = "$PSScriptRoot\posts"
$public = "$PSScriptRoot\public"
$tmpl   = "$PSScriptRoot\template.html"
$imgsrc = "$PSScriptRoot\source\images"

# Clean and recreate public
if (Test-Path $public) { Remove-Item -Recurse -Force $public }
New-Item -ItemType Directory -Path $public | Out-Null

# Copy images
if (Test-Path $imgsrc) {
    Copy-Item -Recurse "$imgsrc" "$public\images"
}

# Build each post
$entries = New-Object System.Collections.ArrayList
Get-ChildItem "$posts\*.md" | ForEach-Object {
    $name = $_.BaseName
    $out  = "$public\$name.html"

    & $pandoc $_.FullName `
        --template=$tmpl `
        --from=markdown+auto_identifiers `
        --to=html5 `
        --standalone `
        -o $out

    # Read generated HTML
    $html = [System.IO.File]::ReadAllText($out, [System.Text.UTF8Encoding]::new($false))

    # Extract title
    $title = ""
    if ($html -match '<h1>(.+?)</h1>') { $title = $matches[1] }
    if (-not $title) { $title = $name }

    # Extract date
    $date = ""
    if ($html -match '<div class="date">(.+?)</div>') { $date = $matches[1] }

    # Extract preview from body content only
    $body = ""
    if ($html -match '(?s)<body>(.*?)</body>') { $body = $matches[1] }
    $plain = $body -replace '<h1>.+?</h1>', ''
    $plain = $plain -replace '<[^>]+>', ''
    $plain = $plain -replace '\s+', ' '
    $plain = $plain.Trim()
    # Clean up template artifacts
    $plain = $plain -replace '^Blog ', ''
    $plain = $plain -replace '^\d{4}-\d{2}-\d{2} ', ''
    $plain = $plain -replace ' ← 返回.*', ''
    $plain = $plain.Trim()
    if ($plain.Length -gt 200) {
        $cut = $plain.Substring(0, 200)
        $lastSpace = $cut.LastIndexOf(' ')
        if ($lastSpace -gt 100) { $cut = $cut.Substring(0, $lastSpace) }
        $preview = $cut.TrimEnd() + "..."
    } else {
        $preview = $plain
    }

    $null = $entries.Add(@{ file = $name; title = $title; date = $date; preview = $preview })
    Write-Host "  $name.html"
}

# Sort by date descending and build index items
$items = New-Object System.Text.StringBuilder
$entries | Sort-Object { if ($_.date) { $_.date } else { "0000-00-00" } } -Descending | ForEach-Object {
    $t = [System.Net.WebUtility]::HtmlEncode($_.title)
    $p = [System.Net.WebUtility]::HtmlEncode($_.preview)
    $d = [System.Net.WebUtility]::HtmlEncode($_.date)
    $null = $items.AppendLine("  <div class='index-item'>")
    $null = $items.AppendLine("    <div class='index-meta'><span class='date'>$d</span></div>")
    $null = $items.AppendLine("    <a class='index-title' href='$($_.file).html'>$t</a>")
    $null = $items.AppendLine("    <div class='index-preview'>$p</div>")
    $null = $items.AppendLine("  </div>")
}

$indexHtml = @"
<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Blog</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    max-width: 720px;
    margin: 0 auto;
    padding: 32px 20px 80px;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    font-size: 16px;
    line-height: 1.7;
    color: #222;
    background: #fff;
  }
  h1 { font-size: 24px; margin-bottom: 24px; }
  .index-item { padding: 16px 0; border-bottom: 1px solid #eee; }
  .index-item:last-child { border-bottom: none; }
  .index-title { font-size: 17px; font-weight: 600; color: #222; text-decoration: none; }
  .index-title:hover { color: #0366d6; }
  .index-preview { color: #666; font-size: 14px; line-height: 1.6; margin-top: 4px; }
  .index-meta { margin-bottom: 2px; }
  .index-meta .date { color: #888; font-size: 13px; }
</style>
</head>
<body>
<h1>Posts</h1>
$($items.ToString())
</body>
</html>
"@

[System.IO.File]::WriteAllText("$public\index.html", $indexHtml, [System.Text.UTF8Encoding]::new($false))
Write-Host "  index.html"
Write-Host ""
Write-Host "Done. Open public/index.html"
