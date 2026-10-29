#!/usr/bin/env bash
# Read-only inventory for old MonoPost/PegiNelab WSL projects.
set -euo pipefail
[[ "$(id -u)" -ne 0 ]] || { echo "Run as normal WSL user, not sudo/root" >&2; exit 2; }
[[ "$HOME" == /home/* && -d "$HOME" ]] || { echo "Unexpected HOME: $HOME" >&2; exit 2; }
echo "IRINA :: Legacy WSL audit | user=$(id -un) | HOME=$HOME"
echo "NO CHANGES. Secrets and file contents are never printed."
printf '\n%-51s %12s  %s\n' "EXACT HOME DIRECTORY" "DISK USAGE" "STATUS"
while IFS= read -r name; do
  p="$HOME/$name"
  if [[ -L "$p" ]]; then
    printf '%-51s %12s  %s\n' "$name" "-" "SYMLINK protected"
  elif [[ -d "$p" ]]; then
    size="$(du -sh -- "$p" 2>/dev/null | cut -f1 || true)"
    if mountpoint -q "$p"; then
      printf '%-51s %12s  %s\n' "$name" "$size" "MOUNTPOINT protected"
    else
      printf '%-51s %12s  %s\n' "$name" "$size" "candidate"
    fi
  else
    printf '%-51s %12s  %s\n' "$name" "-" "not present"
  fi
done <<'NAMES'
peginelab
peginelab.before-cert-fix-20261028-185616
peginelab.before-ssl-20261028-131339
peginelabcrt
peginelab-deploy-backups
peginelab.old-20261028-183414
peginelab-studio
monopost
monopostcrt
monopost-data
monopost-deploy
monopost-deploy-2wan
NAMES
printf '\nPROTECTED OUT OF SCOPE:\n'
echo 'vpn-stack, crt-cert, 2FA files, credentials, unlisted folders, WSL distros, Windows disks, F drive.'
printf '\nDocker inventory (may be a shared Docker Desktop daemon):\n'
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI not installed."
elif ! docker info --format '{{.ServerVersion}}' >/dev/null 2>&1; then
  echo "Docker daemon unavailable or permission denied. No Docker changes."
else
  echo "Context: $(docker context show 2>/dev/null || true)"
  echo "Compose projects (all; read-only):"
  docker compose ls -a 2>/dev/null || true
  echo "Containers / Compose labels:"
  docker ps -a --format 'Name={{.Names}} | Compose={{.Label "com.docker.compose.project"}} | Status={{.Status}}'
  echo "Volume names / Compose labels (never their contents):"
  docker volume ls --format '{{.Name}} | project={{.Label "com.docker.compose.project"}}'
  echo "Docker disk usage:"
  docker system df || true
fi
echo "AUDIT ONLY: nothing has been deleted."
