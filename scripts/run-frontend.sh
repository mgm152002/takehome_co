#!/usr/bin/env bash
# Run the Vite dev server (proxies /api to the Spring backend on :8080).
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec npm --prefix "$project_dir/frontend" run dev -- --host 127.0.0.1 --port 5173
