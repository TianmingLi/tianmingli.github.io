#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
POSTS="$ROOT/posts"
PUBLIC="$ROOT/public"
TMPL="$ROOT/template.html"
IMGSRC="$ROOT/source/images"

# Clean and recreate public
rm -rf "$PUBLIC"
mkdir -p "$PUBLIC"

# Copy images
if [ -d "$IMGSRC" ]; then
    cp -r "$IMGSRC" "$PUBLIC/images"
fi

# Build each post and collect metadata
entries_file=$(mktemp)
for md in "$POSTS"/*.md; do
    name="$(basename "$md" .md)"
    out="$PUBLIC/$name.html"

    pandoc "$md" \
        --template="$TMPL" \
        --from=markdown+auto_identifiers \
        --to=html5 \
        --standalone \
        -o "$out"

    title=$(grep -oP '<h1>\K.*?(?=</h1>)' "$out" | head -1)
    [ -z "$title" ] && title="$name"
    date=$(grep -oP '<div class="date">\K.*?(?=</div>)' "$out" | head -1)

    # Generate plain-text preview from body only
    body=$(sed -n '/<body>/,/<\/body>/p' "$out" | sed '1s/.*<body>//; $s/<\/body>.*//')
    preview=$(echo "$body" | sed 's/<[^>]*>//g' | sed "s/$title//" | tr -s '[:space:]' ' ' | sed 's/^ *//' | head -c 250)
    # Strip template artifacts
    preview=$(echo "$preview" | sed "s/^Blog //; s/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} //; s/ ← 返回.*//")
    # Truncate at last space before 200
    if [ ${#preview} -gt 200 ]; then
        preview="${preview:0:200}"
        preview="${preview% *}..."
    fi

    # Escape special chars for sed replacement
    title_esc=$(echo "$title" | sed 's/&/\\\&/g; s/\//\\\//g')
    date_esc=$(echo "$date" | sed 's/&/\\\&/g; s/\//\\\//g')
    preview_esc=$(echo "$preview" | sed 's/&/\\\&/g; s/\//\\\//g')

    echo "$name.html|$title_esc|$date_esc|$preview_esc" >> "$entries_file"
    echo "  $name.html"
done

items=""
while IFS="|" read -r file title date preview; do
    items="$items  <div class='index-item'>
    <div class='index-meta'><span class='date'>$date</span></div>
    <a class='index-title' href='$file'>$title</a>
    <div class='index-preview'>$preview</div>
  </div>
"
done < <(sort -t"|" -k3 -r "$entries_file")
rm -f "$entries_file"

# Write index.html
cat > "$PUBLIC/index.html" << HTMLEOF
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
HTMLEOF

echo -e "$items" >> "$PUBLIC/index.html"

cat >> "$PUBLIC/index.html" << HTMLEOF
</body>
</html>
HTMLEOF

echo "  index.html"
echo ""
echo "Done. Open public/index.html"
