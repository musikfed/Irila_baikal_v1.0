#!/usr/bin/env bash
# Prepare installed writable system, reusing existing Acer driver profile.
set -Eeuo pipefail
umask 022
STAGE=""
PROFILE="core"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
die(){ echo "IRINA INSTALLED PREP ERROR: $*" >&2; exit 1; }
cleanup(){
  code=$?; trap - EXIT
  if [[ -n "$STAGE" ]]; then
    for part in run sys proc dev; do
      mountpoint -q "$STAGE/$part" && umount -R "$STAGE/$part" || true
    done
    rm -f "$STAGE/usr/sbin/policy-rc.d" "$STAGE/etc/resolv.conf"
  fi
  exit "$code"
}
trap cleanup EXIT
while (($#)); do
  case "$1" in
    --stage) STAGE="$2"; shift 2;;
    --core) PROFILE=core; shift;;
    --full) PROFILE=full; shift;;
    *) die "Usage: --stage /srv/irina/rootfs [--core|--full]";;
  esac
done
(( EUID == 0 )) || die 'Run as root in CI'
[[ "$STAGE" == /* && ! -e "$STAGE" && "$STAGE" != / && "$STAGE" != /dev/* && "$STAGE" != /mnt/* ]] || die 'Refuse dangerous or existing stage'
# Common builder already includes Acer AMD/QCA firmware, XFCE, Irina Shell,
# Hrag and RU/EN. Do not re-discover owner's hardware from scratch.
bash "$REPO/scripts/prepare_source.sh" --stage "$STAGE" "--$PROFILE"
for part in dev proc sys run; do
  mount --rbind "/$part" "$STAGE/$part"
  mount --make-rslave "$STAGE/$part"
done
cp -L /etc/resolv.conf "$STAGE/etc/resolv.conf"
cat > "$STAGE/usr/sbin/policy-rc.d" <<'POLICY'
#!/bin/sh
exit 101
POLICY
chmod +x "$STAGE/usr/sbin/policy-rc.d"
export DEBIAN_FRONTEND=noninteractive
echo "IRINA INSTALLED: remove live-only Casper and install ext4 USB/root utilities."
chroot "$STAGE" apt-get update
chroot "$STAGE" apt-get purge -y casper
# Keep initial image compact: desktop apps are installed later when Wi-Fi works.
chroot "$STAGE" apt-get install -y --no-install-recommends \
  cloud-guest-utils gdisk e2fsprogs util-linux pciutils usbutils \
  sudo python3-gi gir1.2-gtk-3.0 xfce4-screenshooter \
  curl wget ca-certificates
cat > "$STAGE/etc/fstab" <<'FSTAB'
LABEL=IRINA_ROOT / ext4 defaults,noatime,errors=remount-ro 0 1
LABEL=IRINA_EFI /boot/efi vfat umask=0077,nofail 0 2
FSTAB
echo IRINA_INSTALLED_USB_R1 > "$STAGE/etc/irina-installed-marker"
mkdir -p "$STAGE/boot/efi" "$STAGE/var/lib/irina" "$STAGE/usr/share/irina" "$STAGE/etc/xdg/autostart"
printf '%s\n' 'Подготовка системы: подключите Wi-Fi для автоматической установки программ.' > "$STAGE/var/lib/irina/setup-status"
install -m 0755 "$REPO/scripts/irina_grow_usb_root.sh" "$STAGE/usr/local/sbin/irina-grow-usb-root"
install -m 0755 "$REPO/scripts/irina_auto_provision.sh" "$STAGE/usr/local/sbin/irina-auto-provision"
install -m 0644 "$REPO/hardware/acer_swift3_sf314-41.json" "$STAGE/usr/share/irina/hardware-profile.json"
install -m 0755 "$REPO/ui/irina_setup_status.py" "$STAGE/opt/irina/ui/irina_setup_status.py"
cat > "$STAGE/etc/xdg/autostart/irina-setup.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Irina Baikal — Настройка системы
Exec=/usr/bin/python3 /opt/irina/ui/irina_setup_status.py
Terminal=false
OnlyShowIn=XFCE;
DESKTOP
cat > "$STAGE/etc/systemd/system/irina-grow-root.service" <<'SERVICE'
[Unit]
Description=Irina guarded resize of its own external USB root partition
After=local-fs.target
ConditionPathExists=/etc/irina-installed-marker
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/irina-grow-usb-root
[Install]
WantedBy=multi-user.target
SERVICE
cat > "$STAGE/etc/systemd/system/irina-auto-provision.service" <<'SERVICE'
[Unit]
Description=Irina unattended software setup after Wi-Fi connects
Wants=NetworkManager.service
After=NetworkManager.service irina-grow-root.service
ConditionPathExists=/etc/irina-installed-marker
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/irina-auto-provision
[Install]
WantedBy=multi-user.target
SERVICE
cat > "$STAGE/etc/systemd/system/irina-auto-provision.timer" <<'TIMER'
[Unit]
Description=Retry automatic software setup when Wi-Fi is available
[Timer]
OnBootSec=3min
OnUnitInactiveSec=10min
Unit=irina-auto-provision.service
Persistent=true
[Install]
WantedBy=timers.target
TIMER
chroot "$STAGE" systemctl enable irina-grow-root.service irina-auto-provision.timer
# Core drivers are already present; kernel autodetects hardware.
printf 'MODULES=most\n' > "$STAGE/etc/initramfs-tools/conf.d/irina-modules"
for module in usb_storage uas xhci_pci xhci_hcd nvme ext4 amdgpu ath10k_pci snd_hda_intel uvcvideo; do
  grep -qx "$module" "$STAGE/etc/initramfs-tools/modules" || echo "$module" >> "$STAGE/etc/initramfs-tools/modules"
done
chroot "$STAGE" update-initramfs -u -k all
[[ ! -f "$STAGE/usr/share/initramfs-tools/scripts/casper-premount" ]] || die 'Casper still present'
chroot "$STAGE" apt-get clean
rm -rf "$STAGE/var/lib/apt/lists/"*
[[ -s "$STAGE/etc/fstab" && -s "$STAGE/etc/irina-installed-marker" ]] || die 'Missing installed root metadata'
echo "IRINA INSTALLED: writable ext4, guarded root growth, GTK status, automatic apps after Wi-Fi."
