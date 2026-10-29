#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v uv >/dev/null 2>&1; then
  echo "Install uv first, or use python3 -m venv .venv and pip." >&2
  exit 1
fi
if [[ ! -x ".venv/bin/python" ]]; then
  uv venv --python 3.12 .venv
fi
uv pip install --python ".venv/bin/python" -r browser/requirements.txt
exec ".venv/bin/python" browser/main.py
