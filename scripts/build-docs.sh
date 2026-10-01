#!/usr/bin/env bash
# Build the AsciiDoc technical manual into build/docs/.
# Generic: no project names; reuse across repositories by adjusting
# SRC/OUT below. Never installs dependencies; fails fast with guidance.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/docs/index.adoc"
OUT="$ROOT/build/docs"

if ! command -v asciidoctor >/dev/null 2>&1; then
  echo "error: asciidoctor not found." >&2
  echo "" >&2
  echo "Install the minimum dependency and retry:" >&2
  echo "  macOS:        brew install asciidoctor" >&2
  echo "  Ubuntu/Debian: sudo apt-get install -y asciidoctor" >&2
  echo "  Any (gem):    gem install asciidoctor" >&2
  echo "" >&2
  echo "Optional (source highlighting): gem install rouge" >&2
  exit 1
fi

if [ ! -f "$SRC" ]; then
  echo "error: entry point not found: $SRC" >&2
  exit 1
fi

mkdir -p "$OUT/theme" "$OUT/images"

# Single-page manual. Attributes mirror docs/index.adoc; -a flags here
# only set safe defaults and must not hardcode project identity.
asciidoctor \
  -D "$OUT" \
  -o index.html \
  "$SRC"

# Theme assets referenced by docs/theme/docinfo.html.
cp "$ROOT/docs/theme/docs.css" "$OUT/theme/docs.css"
cp "$ROOT/docs/theme/nav.js" "$OUT/theme/nav.js"

# Figures referenced via :imagesdir: images.
if [ -d "$ROOT/docs/images" ]; then
  cp -r "$ROOT/docs/images/." "$OUT/images/"
fi

if [ ! -f "$OUT/index.html" ]; then
  echo "error: build produced no index.html" >&2
  exit 1
fi

# Bypass Jekyll processing on GitHub Pages (future-proof for
# underscore-prefixed asset paths).
touch "$OUT/.nojekyll"

echo "docs built: $OUT/index.html"
