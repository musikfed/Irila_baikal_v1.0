#!/usr/bin/env bash
# Play after interactive Ubuntu desktop login; never blocks shell startup.
set -euo pipefail
if [[ -f "${HOME}/.config/irina/disable-intro" || "${IRINA_DISABLE_INTRO:-0}" == 1 ]]; then
  exit 0
fi
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="${BASE}/ui/web/assets/irina_intro.mp3"
if [[ ! -r "${FILE}" ]]; then
  echo "Irina intro not installed: ${FILE}" >&2
  exit 0
fi
if command -v mpg123 >/dev/null 2>&1; then
  exec mpg123 -q "${FILE}"
elif command -v ffplay >/dev/null 2>&1; then
  exec ffplay -hide_banner -loglevel error -nodisp -autoexit "${FILE}"
else
  echo 'Irina intro: install mpg123 (or ffmpeg with ffplay) to enable sound.' >&2
fi
