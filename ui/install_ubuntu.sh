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
echo 'Installed. Sign out and back in to start Irina Shell.'
