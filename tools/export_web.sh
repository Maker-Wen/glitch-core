#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html

cat <<'MSG'

Web build exported to build/web/index.html

Share the entire build/web directory, not only index.html.
Preview locally with:
  ./tools/serve_web.sh
MSG

