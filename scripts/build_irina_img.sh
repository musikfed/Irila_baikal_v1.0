#!/usr/bin/env bash
# IRINA BAIKAL: builds a NEW raw disk IMAGE, not a physical drive.
# Ubuntu 24.04 builder VM only. Prototype: writable ext4 root, no Secure Boot.
set -Eeuo pipefail
umask 077
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
REPO="$(cd -- "$SCRIPT_DIR/.." && pwd)"
OUT=""
PROFILE="full"
YES=0
LOOP=""
MNT=""
FAILED=1

help() {
  echo "Usage: sudo bash scripts/build_irina_img.sh --output /srv/irina/irina_baikal_1.0.img [--full|--core] [--yes]"
  echo "Only creates a new 16 GiB image file; NEVER selects a physical SSD."
  echo "Run only in Ubuntu 24.04 x86_64 VM with debootstrap, parted, dosfstools,"
  echo "e2fsprogs, grub-efi-amd64-bin, grub2-common, rsync, python3, ubuntu-keyring."
}
die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[IRINA] $*"; }
cleanup() {
  result=$?
  trap - EXIT
  set +e
  if [[ -n "$MNT" ]]; then
    for sub in /run /sys /proc /dev /home /boot/efi ""; do
      mountpoint -q "$MNT$sub" && umount -R "$MNT$sub"
    done
    rmdir "$MNT" 2>/dev/null
  fi
  if [[ -n "$LOOP" ]]; then losetup -d "$LOOP"; fi
  if [[ "$FAILED" -eq 1 && -n "$OUT" && -e "$OUT" ]]; then
    touch "$OUT.FAILED"
    echo "INCOMPLETE IMAGE (do not flash): $OUT" >&2
  fi
  exit "$result"
}
trap cleanup EXIT

while (($#)); do
  case "$1" in
    --output) (($#>=2)) || die "Missing output"; OUT="$2"; shift 2 ;;
    --core) PROFILE=core; shift ;;
    --full) PROFILE=full; shift ;;
    --yes) YES=1; shift ;;
    --help|-h) help; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done
((EUID==0)) || die "Use sudo inside Ubuntu 24.04 VM"
[[ "$(uname -m)" == x86_64 ]] || die "Need x86_64"
source /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 24.04 ]] || die "Builder must be Ubuntu 24.04"
[[ "$OUT" == /* && "$OUT" == *.img && "$OUT" != /dev/* ]] || die "Supply absolute regular .img file path (not /dev)"
[[ ! -e "$OUT" && ! -L "$OUT" ]] || die "Refusing to overwrite $OUT"
[[ -f "$REPO/ui/irina_shell.py" ]] || die "Clone full IrinaBaikal GitHub repo"
for c in debootstrap parted partprobe losetup udevadm mkfs.vfat mkfs.ext4 grub-install rsync chroot sha256sum python3; do
  command -v "$c" >/dev/null || die "Install missing build tool: $c"
done
log "IMAGE: $OUT | $PROFILE | 16 GiB virtual GPT"
log "NO access to any /dev/sdX or /dev/nvme physical disk"
log "MVP writable ext4 root, unsigned EFI GRUB, no SquashFS yet"
if ((YES==0)); then
  read -r -p "Enter BUILD to proceed (creates image FILE only): " answer
  [[ "$answer" == BUILD ]] || die "Cancelled"
fi
mkdir -p "$(dirname "$OUT")"
truncate -s 16G "$OUT"
LOOP="$(losetup --find --show --partscan "$OUT")"
[[ "$LOOP" =~ ^/dev/loop[0-9]+$ ]] || die "Not a loop device: $LOOP"
parted --script "$LOOP" mklabel gpt
parted --script "$LOOP" mkpart EFI fat32 1MiB 513MiB
parted --script "$LOOP" set 1 esp on
parted --script "$LOOP" mkpart SYSTEM ext4 513MiB 12801MiB
parted --script "$LOOP" mkpart DATA ext4 12801MiB 100%
partprobe "$LOOP"; udevadm settle
P1="$LOOP"p1; P2="$LOOP"p2; P3="$LOOP"p3
for p in "$P1" "$P2" "$P3"; do [[ -b "$p" ]] || die "Missing loop partition $p"; done
mkfs.vfat -F32 -n IRINA_EFI "$P1"
mkfs.ext4 -F -q -m0 -L IRINA_ROOT "$P2"
mkfs.ext4 -F -q -m0 -L IRINA_DATA "$P3"
MNT="$(mktemp -d /var/tmp/irina-root.XXXXXXXX)"
mount "$P2" "$MNT"
mkdir -p "$MNT/boot/efi" "$MNT/home"
mount "$P1" "$MNT/boot/efi"
log "Bootstrapping Ubuntu Noble (network access needed)"
debootstrap --arch amd64 --components=main,restricted,universe \
  --include=ubuntu-keyring,ca-certificates noble "$MNT" http://archive.ubuntu.com/ubuntu
cat > "$MNT/etc/apt/sources.list" <<'SOURCES'
deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse
SOURCES
cp -L /etc/resolv.conf "$MNT/etc/resolv.conf"
cat > "$MNT/usr/sbin/policy-rc.d" <<'POLICY'
#!/bin/sh
exit 101
POLICY
chmod 755 "$MNT/usr/sbin/policy-rc.d"
for mountname in dev proc sys run; do
  mount --rbind "/$mountname" "$MNT/$mountname"
  mount --make-rslave "$MNT/$mountname"
done
export DEBIAN_FRONTEND=noninteractive
chroot "$MNT" apt-get update
log "Installing kernel, AMD firmware, Qualcomm Wi-Fi firmware and XFCE"
chroot "$MNT" apt-get install -y --no-install-recommends \
  linux-image-generic linux-firmware initramfs-tools systemd-sysv sudo \
  network-manager network-manager-gnome \
  xorg xserver-xorg-input-libinput lightdm lightdm-gtk-greeter \
  xfce4 xfce4-terminal xfce4-goodies \
  pipewire pipewire-pulse wireplumber alsa-utils pavucontrol \
  libgl1-mesa-dri mesa-vulkan-drivers \
  python3 dbus-x11 xdg-utils epiphany-browser mpg123 \
  locales language-pack-ru language-pack-en fonts-dejavu-core \
  ca-certificates curl vim less
if [[ "$PROFILE" == full ]]; then
  log "Installing full office, graphics, mail, SIP and games"
  chroot "$MNT" apt-get install -y --no-install-recommends \
    libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-draw \
    libreoffice-base libreoffice-math libreoffice-l10n-ru \
    gimp inkscape thunderbird linphone-desktop \
    aisleriot gnome-mines gnome-mahjongg
else
  chroot "$MNT" apt-get install -y --no-install-recommends \
    libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-draw thunderbird
fi
echo irina-baikal > "$MNT/etc/hostname"
cat > "$MNT/etc/hosts" <<'HOSTS'
127.0.0.1 localhost
127.0.1.1 irina-baikal
::1 localhost ip6-localhost ip6-loopback
HOSTS
cat > "$MNT/etc/default/keyboard" <<'KEYBOARD'
XKBMODEL="pc105"
XKBLAYOUT="us,ru"
XKBVARIANT=","
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
KEYBOARD
chroot "$MNT" locale-gen ru_RU.UTF-8 en_US.UTF-8
echo 'LANG=ru_RU.UTF-8' > "$MNT/etc/default/locale"
chroot "$MNT" useradd -m -s /bin/bash -G sudo,audio,video,plugdev irina
PASS="$(python3 -c 'import secrets; print(secrets.token_urlsafe(18))')"
printf 'irina:%s\n' "$PASS" | chroot "$MNT" chpasswd
printf 'User: irina\nTemporary local password: %s\n' "$PASS" > "$OUT.login.txt"
chmod 600 "$OUT.login.txt"
unset PASS
cat > "$MNT/etc/lightdm/lightdm.conf" <<'LOGIN'
[Seat:*]
autologin-user=irina
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
LOGIN
mkdir -p "$MNT/opt/irina/ui" "$MNT/opt/irina/audio" "$MNT/etc/xdg/autostart"
rsync -a "$REPO/ui/" "$MNT/opt/irina/ui/"
if [[ -f "$REPO/audio/play_intro.sh" ]]; then
  install -m 755 "$REPO/audio/play_intro.sh" "$MNT/opt/irina/audio/play_intro.sh"
fi
cat > "$MNT/etc/xdg/autostart/irina-shell.desktop" <<'SHELLENTRY'
[Desktop Entry]
Type=Application
Name=Ирина Байкал — рабочий стол
Exec=/usr/bin/python3 /opt/irina/ui/irina_shell.py
Terminal=false
OnlyShowIn=XFCE;
SHELLENTRY
if [[ -f "$MNT/opt/irina/ui/web/assets/irina_intro.mp3" ]]; then
  cat > "$MNT/etc/xdg/autostart/irina-intro.desktop" <<'INTROENTRY'
[Desktop Entry]
Type=Application
Name=Ирина Байкал — звуковое приветствие
Exec=/bin/bash /opt/irina/audio/play_intro.sh
Terminal=false
OnlyShowIn=XFCE;
INTROENTRY
fi
mkdir -p "$MNT/etc/NetworkManager/conf.d"
chroot "$MNT" systemctl enable NetworkManager.service lightdm.service
cat > "$MNT/etc/fstab" <<'FSTAB'
LABEL=IRINA_ROOT / ext4 defaults,noatime,errors=remount-ro 0 1
LABEL=IRINA_EFI /boot/efi vfat umask=0077 0 2
LABEL=IRINA_DATA /home ext4 defaults,noatime 0 2
FSTAB
chroot "$MNT" update-initramfs -u -k all
KERNEL="$(find "$MNT/boot" -maxdepth 1 -name 'vmlinuz-*' -type f | sort -V | tail -1)"
[[ -n "$KERNEL" ]] || die "Kernel was not installed"
VER="$(basename "$KERNEL" | sed 's/^vmlinuz-//')"
[[ -s "$MNT/boot/initrd.img-$VER" ]] || die "Missing initramfs"
mount "$P3" "$MNT/home"
chroot "$MNT" chown -R irina:irina /home/irina
chroot "$MNT" apt-get clean
rm -f "$MNT/usr/sbin/policy-rc.d"
mkdir -p "$MNT/boot/grub"
cat > "$MNT/boot/grub/grub.cfg" <<EOF
set timeout=5
set default=0
insmod part_gpt
insmod ext2
menuentry "Irina Baikal 1.0 / Ubuntu 24.04" {
  search --no-floppy --label IRINA_ROOT --set=root
  linux /boot/vmlinuz-$VER root=LABEL=IRINA_ROOT rw quiet
  initrd /boot/initrd.img-$VER
}
menuentry "Irina Baikal 1.0 / rescue text login" {
  search --no-floppy --label IRINA_ROOT --set=root
  linux /boot/vmlinuz-$VER root=LABEL=IRINA_ROOT rw systemd.unit=multi-user.target
  initrd /boot/initrd.img-$VER
}
EOF
log "Installing removable UEFI GRUB to the IMAGE ESP; no host NVRAM change"
grub-install --target=x86_64-efi --efi-directory="$MNT/boot/efi" \
  --boot-directory="$MNT/boot" --removable --no-nvram --recheck
[[ -s "$MNT/boot/efi/EFI/BOOT/BOOTX64.EFI" ]] || die "EFI loader missing"
sync
# The main volume is unmounted before hashing to ensure a stable checksum.
for sub in /run /sys /proc /dev /home /boot/efi ""; do
  if mountpoint -q "$MNT$sub"; then umount -R "$MNT$sub"; fi
done
rmdir "$MNT"; MNT=""
losetup -d "$LOOP"; LOOP=""
sha256sum "$OUT" > "$OUT.sha256"
FAILED=0
log "Created: $OUT"
log "Verify:  $OUT.sha256"
log "Login:   $OUT.login.txt (PRIVATE; do not push to GitHub)"
log "NEXT: QEMU/OVMF boot test, then flash EXTERNAL USB SSD with Rufus."
log "This version has writable root + unencrypted DATA; NOT final SquashFS image."
