#!/bin/bash
# Renders cheatsheet.html to cheatsheet.pdf next to it, checks that it is one A4 page,
# and writes a PNG preview to .tmp/ in the repo.
set -euo pipefail

dir=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$dir/../.." && pwd)
html="$dir/cheatsheet.html"
pdf="$dir/cheatsheet.pdf"
tmp="$repo/.tmp"

chrome=""
for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium" \
  google-chrome google-chrome-stable chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then
    chrome=$(command -v "$c")
    break
  fi
done
if [ -z "$chrome" ]; then
  echo "Chrome or Chromium not found" >&2
  exit 1
fi

mkdir -p "$tmp"
log="$tmp/cheatsheet-chrome.log"
# The fonts come from Google Fonts. The time budget gives them time to load before the print.
if ! "$chrome" --headless=new --disable-gpu --no-first-run --no-default-browser-check \
  --user-data-dir="$tmp/cheatsheet-chrome" --no-pdf-header-footer --virtual-time-budget=15000 \
  --print-to-pdf="$pdf" "file://$html" >"$log" 2>&1; then
  cat "$log" >&2
  exit 1
fi
echo "PDF: $pdf"

if ! command -v pdfinfo >/dev/null 2>&1; then
  echo "pdfinfo not found (poppler): skipped the page and font checks" >&2
  exit 0
fi

pages=$(pdfinfo "$pdf" | awk '/^Pages:/ { print $2 }')
if [ "$pages" != 1 ]; then
  echo "The PDF has $pages pages, it must be 1" >&2
  exit 1
fi

fonts=$(pdffonts "$pdf")
for f in DelaGothicOne MPLUS1Code ZenKakuGothicNew; do
  if ! grep -q "$f" <<<"$fonts"; then
    echo "Font $f is not in the PDF. Check the network and render again." >&2
    exit 1
  fi
done

rm -f "$tmp"/cheatsheet-preview-*.png
pdftoppm -r "${1:-110}" -png "$pdf" "$tmp/cheatsheet-preview"
echo "Preview: $(ls "$tmp"/cheatsheet-preview-*.png)"
