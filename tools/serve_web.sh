#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_DIR="$ROOT_DIR/build/web"
PORT="${1:-8060}"

if [[ ! -f "$WEB_DIR/index.html" ]]; then
  echo "Missing $WEB_DIR/index.html"
  echo "Run ./tools/export_web.sh first."
  exit 1
fi

echo "Serving $WEB_DIR"
echo "Open http://127.0.0.1:$PORT/"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$WEB_DIR"

