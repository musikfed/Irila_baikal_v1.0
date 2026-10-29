#!/usr/bin/env bash
# Opt-in XFCE session autostart; does not replace UEFI, initramfs or login manager.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null || { echo 'Python 3 is required'; exit 1; }
command -v xdg-open >/dev/null || { echo 'xdg-open is required'; exit 1; }
echo 'Installing Irina Shell UI in /opt/irina/ui (requires sudo).'
sudo mkdir -p /opt/irina/ui /etc/xdg/autostart
sudo cp -a "$HERE"/. /opt/irina/ui/
cat <<'DESKTOP' | sudo tee /etc/xdg/autostart/irina-shell.desktop >/dev/null
[Desktop Entry]
Type=Application
Name=Ирина Байкал — оболочка
Comment=Irina Shell local desktop prototype
Exec=/usr/bin/python3 /opt/irina/ui/irina_shell.py
Terminal=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=XFCE;GNOME;
DESKTOP
# Optional login sound: install only if the generated MP3 was shipped in this checkout.
ROOT="$(cd "$HERE/.." && pwd)"
if [[ -f "$HERE/web/assets/irina_intro.mp3" && -f "$ROOT/audio/play_intro.sh" ]]; then
  sudo mkdir -p /opt/irina/audio
  sudo install -m 755 "$ROOT/audio/play_intro.sh" /opt/irina/audio/play_intro.sh
  cat <<'INTRO_DESKTOP' | sudo tee /etc/xdg/autostart/irina-intro.desktop >/dev/null
[Desktop Entry]
Type=Application
Name=Ирина Байкал — звуковое приветствие
Comment=Original sound plays once after desktop login
Exec=/bin/bash /opt/irina/audio/play_intro.sh
Terminal=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=XFCE;GNOME;
INTRO_DESKTOP
  if ! command -v mpg123 >/dev/null 2>&1 && ! command -v ffplay >/dev/null 2>&1; then
    echo 'Note: install mpg123 or ffplay to hear the intro after desktop login.'
  fi
else
  echo 'Intro MP3 is missing; skipping audio autostart registration.'
fi
echo 'Installed. Sign out and back in to start Irina Shell.'
