#!/usr/bin/env bash
# Ubuntu 24.04 -> isolated Irina Baikal Live rootfs. No physical disk access.
set -Eeuo pipefail
umask 022
STAGE=""; PROFILE="core"; OLLAMA_BIN=""; OLLAMA_MODELS=""
REPO="$(cd "$(dirname "$0")/.." && pwd)"
MOUNTED=()
help(){ echo "Usage: sudo bash scripts/prepare_source.sh --stage /srv/irina/rootfs [--core|--full] [--ollama-bin /path/to/linux-ollama] [--ollama-models /path/to/models]"; }
die(){ echo "IRINA: $*" >&2; exit 1; }
cleanup(){
  code=$?
  trap - EXIT
  for ((i=${#MOUNTED[@]}-1; i>=0; i--)); do
    mountpoint -q "${MOUNTED[$i]}" && umount -R "${MOUNTED[$i]}" || true
  done
  exit "$code"
}
trap cleanup EXIT
while (($#)); do
  case "$1" in
    --stage) STAGE="$2"; shift 2;;
    --core) PROFILE=core; shift;;
    --full) PROFILE=full; shift;;
    --ollama-bin) OLLAMA_BIN="$2"; shift 2;;
    --ollama-models) OLLAMA_MODELS="$2"; shift 2;;
    -h|--help) help; exit 0;;
    *) die "Unknown option $1";;
  esac
done
((EUID==0)) || die 'Run in Ubuntu environment as root'
[[ "$STAGE" == /* && "$STAGE" != /dev/* && "$STAGE" != /mnt/* ]] || die 'Stage must be absolute path on Linux filesystem, not Windows /mnt'
[[ "$STAGE" != / && "$STAGE" != /home && "$STAGE" != /usr ]] || die 'Unsafe stage'
[[ ! -e "$STAGE" && ! -L "$STAGE" ]] || die 'Refusing to modify existing directory'
source /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 24.04 ]] || die 'Need Ubuntu 24.04 WSL2 or Live USB (not Windows PowerShell)'
[[ "$(uname -m)" == x86_64 ]] || die 'Need x86_64 builder'
for c in debootstrap chroot rsync mount umount; do command -v "$c" >/dev/null || die "Missing: $c"; done
[[ -z "$OLLAMA_BIN" || -f "$OLLAMA_BIN" ]] || die 'Provided Ollama Linux binary missing'
[[ -z "$OLLAMA_MODELS" || -d "$OLLAMA_MODELS" ]] || die 'Provided model directory missing'
[[ -f "$REPO/ui/irina_shell.py" ]] || die 'Run from complete IrinaBaikal GitHub checkout'
mkdir -p "$STAGE"
echo 'IRINA: debootstrap Ubuntu 24.04 Noble'
debootstrap --arch amd64 --components=main,restricted,universe \
  --include=ubuntu-keyring,ca-certificates noble "$STAGE" http://archive.ubuntu.com/ubuntu
cat > "$STAGE/etc/apt/sources.list" <<'SOURCES'
deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse
SOURCES
cp -L /etc/resolv.conf "$STAGE/etc/resolv.conf"
cat > "$STAGE/usr/sbin/policy-rc.d" <<'POLICY'
#!/bin/sh
exit 101
POLICY
chmod +x "$STAGE/usr/sbin/policy-rc.d"
for name in dev proc sys run; do
  mount --rbind "/$name" "$STAGE/$name"
  mount --make-rslave "$STAGE/$name"
  MOUNTED+=("$STAGE/$name")
done
export DEBIAN_FRONTEND=noninteractive
chroot "$STAGE" apt-get update
chroot "$STAGE" apt-get install -y --no-install-recommends \
  casper linux-image-generic linux-firmware initramfs-tools \
  systemd-sysv network-manager network-manager-gnome \
  lightdm lightdm-gtk-greeter xorg xserver-xorg-input-libinput \
  xfce4 xfce4-terminal thunar \
  pipewire pipewire-pulse wireplumber alsa-utils pavucontrol \
  libgl1-mesa-dri mesa-vulkan-drivers \
  epiphany-browser dbus-x11 xdg-utils mpg123 \
  python3 python3-fastapi python3-uvicorn python3-requests python3-bs4 \
  ca-certificates locales language-pack-ru language-pack-en \
  fonts-dejavu-core x11-xkb-utils
if [[ "$PROFILE" == full ]]; then
  echo 'IRINA: installing full office, graphics, mail, SIP and mini-games'
  chroot "$STAGE" apt-get install -y --no-install-recommends \
    libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-draw \
    libreoffice-base libreoffice-math libreoffice-l10n-ru \
    gimp inkscape thunderbird linphone-desktop aisleriot gnome-mines gnome-mahjongg
fi
echo irina-baikal > "$STAGE/etc/hostname"
cat > "$STAGE/etc/hosts" <<'HOSTS'
127.0.0.1 localhost
127.0.1.1 irina-baikal
::1 localhost ip6-localhost ip6-loopback
HOSTS
cat > "$STAGE/etc/default/keyboard" <<'KEYBOARD'
XKBMODEL="pc105"
XKBLAYOUT="us,ru"
XKBVARIANT=","
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
KEYBOARD
chroot "$STAGE" locale-gen ru_RU.UTF-8 en_US.UTF-8
echo LANG=ru_RU.UTF-8 > "$STAGE/etc/default/locale"
chroot "$STAGE" useradd -m -s /bin/bash -G audio,video,plugdev irina
chroot "$STAGE" passwd -l irina
cat > "$STAGE/etc/lightdm/lightdm.conf" <<'LOGIN'
[Seat:*]
autologin-user=irina
autologin-user-timeout=0
user-session=xfce
LOGIN
chroot "$STAGE" systemctl enable NetworkManager.service lightdm.service
chroot "$STAGE" systemctl set-default graphical.target
mkdir -p "$STAGE/etc/xdg/autostart" "$STAGE/opt/irina/ui" "$STAGE/opt/irina/audio" "$STAGE/opt/irina/ai"
rsync -a "$REPO/ui/" "$STAGE/opt/irina/ui/"
install -m 755 "$REPO/audio/play_intro.sh" "$STAGE/opt/irina/audio/play_intro.sh"
cat > "$STAGE/etc/xdg/autostart/irina-shell.desktop" <<'SHELL_ENTRY'
[Desktop Entry]
Type=Application
Name=Irina Baikal Shell
Exec=/usr/bin/python3 /opt/irina/ui/irina_shell.py
Terminal=false
OnlyShowIn=XFCE;
SHELL_ENTRY
if [[ -f "$STAGE/opt/irina/ui/web/assets/irina_intro.mp3" ]]; then
cat > "$STAGE/etc/xdg/autostart/irina-intro.desktop" <<'INTRO_ENTRY'
[Desktop Entry]
Type=Application
Name=Irina Baikal startup sound
Exec=/bin/bash /opt/irina/audio/play_intro.sh
Terminal=false
OnlyShowIn=XFCE;
INTRO_ENTRY
fi
if [[ -f "$REPO/ai/hrag.py" ]]; then
  install -m 644 "$REPO/ai/hrag.py" "$STAGE/opt/irina/ai/hrag.py"
  cat > "$STAGE/etc/systemd/system/irina-hrag.service" <<'HRAG'
[Unit]
Description=Irina Hrag HTML clean service
After=network.target
[Service]
User=irina
WorkingDirectory=/opt/irina/ai
ExecStart=/usr/bin/python3 -m uvicorn hrag:app --host 127.0.0.1 --port 8000
Restart=on-failure
NoNewPrivileges=true
[Install]
WantedBy=multi-user.target
HRAG
  chroot "$STAGE" systemctl enable irina-hrag.service
fi
if [[ -n "$OLLAMA_BIN" ]]; then
  install -m 755 "$OLLAMA_BIN" "$STAGE/usr/local/bin/ollama"
  mkdir -p "$STAGE/usr/share/ollama/.ollama/models"
  if [[ -n "$OLLAMA_MODELS" ]]; then
    rsync -a "$OLLAMA_MODELS/" "$STAGE/usr/share/ollama/.ollama/models/"
  fi
  chroot "$STAGE" useradd --system --no-create-home --shell /usr/sbin/nologin ollama
  cat > "$STAGE/etc/systemd/system/irina-ollama.service" <<'OLLAMA'
[Unit]
Description=Irina local Ollama
After=network.target
[Service]
User=ollama
Environment=OLLAMA_HOST=127.0.0.1:11434
Environment=OLLAMA_MODELS=/usr/share/ollama/.ollama/models
ExecStart=/usr/local/bin/ollama serve
Restart=on-failure
[Install]
WantedBy=multi-user.target
OLLAMA
  chroot "$STAGE" systemctl enable irina-ollama.service
fi
printf 'MODULES=most\n' > "$STAGE/etc/initramfs-tools/conf.d/irina-modules"
for module in usb_storage uas xhci_pci amdgpu ath10k_pci snd_hda_intel uvcvideo squashfs overlay; do
  echo "$module" >> "$STAGE/etc/initramfs-tools/modules"
done
chroot "$STAGE" update-initramfs -u -k all
[[ -n "$(find "$STAGE/boot" -maxdepth 1 -name 'vmlinuz-*' -print -quit)" ]] || die 'No Linux kernel built'
[[ -n "$(find "$STAGE/boot" -maxdepth 1 -name 'initrd.img-*' -print -quit)" ]] || die 'No casper initramfs built'
chroot "$STAGE" apt-get clean
rm -f "$STAGE/usr/sbin/policy-rc.d" "$STAGE/etc/resolv.conf"
rm -rf "$STAGE/var/lib/apt/lists/"*
: > "$STAGE/etc/machine-id"
echo "IRINA: stage ready: $STAGE ($PROFILE)"
