#!/usr/bin/env python3
"""Zero-disk-access tests for the independent installed Acer USB image path."""
import ast
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(file):
    return (ROOT / file).read_text(encoding="utf-8")


class InstalledImageRegression(unittest.TestCase):
    def test_bash_syntax(self):
        for file in (
            "scripts/prepare_installed_source.sh",
            "scripts/bake_image_installed_secureboot.sh",
            "scripts/irina_grow_usb_root.sh",
            "scripts/irina_auto_provision.sh",
        ):
            with self.subTest(file=file):
                subprocess.run(["bash", "-n", str(ROOT / file)], check=True)

    def test_gtk_python_syntax(self):
        code = read("ui/irina_setup_status.py")
        ast.parse(code)
        self.assertIn("gi.require_version", code)
        self.assertIn("setup-status", code)
        self.assertIn("software-ready", code)

    def test_distinct_installed_image(self):
        builder = read("scripts/bake_image_installed_secureboot.sh")
        workflow = read(".github/workflows/build-installed-secureboot-img.yml")
        self.assertIn('[[ "$OUT" == *_installed_secureboot.img ]]', builder)
        self.assertIn("irina_baikal_1.0_installed_secureboot.img", workflow)
        self.assertIn("irina-baikal-1.0-installed-secureboot-img", workflow)
        self.assertNotIn("irina-baikal-1.0-secureboot-r2-img", workflow)
        self.assertIn('[[ ! -e "$OUT" && ! -L "$OUT" ]]', builder)
        self.assertIn('losetup --find --show --partscan "$OUT"', builder)
        self.assertNotIn("mksquashfs", builder)
        self.assertNotIn("boot=casper", builder)
        self.assertIn("root=LABEL=IRINA_ROOT rootwait rw", builder)
        self.assertIn("mkpart IRINA_ROOT ext4", builder)
        self.assertIn('mkfs.ext4 -q -F -m0 -L IRINA_ROOT "$LIVE"', builder)
        self.assertIn('rsync -aHAX --numeric-ids --one-file-system', builder)
        self.assertIn('sbverify --list "$binary"', builder)
        self.assertIn("shimx64.efi.dualsigned", builder)
        self.assertIn('install -m 0644 "$GRUB_SIGNED" "$MNT/EFI/BOOT/grubx64.efi"', builder)
        self.assertIn('sha256sum "$(basename "$OUT")"', builder)
        self.assertIn("sudo mv /srv/irina/irina_baikal_1.0_installed_secureboot.img output/", workflow)
        self.assertIn("sha256sum -c irina_baikal_1.0_installed_secureboot.img.sha256", workflow)

    def test_system_is_installed_not_live(self):
        prep = read("scripts/prepare_installed_source.sh")
        self.assertIn("apt-get purge -y casper", prep)
        self.assertIn("LABEL=IRINA_ROOT / ext4", prep)
        self.assertIn("LABEL=IRINA_EFI /boot/efi vfat", prep)
        self.assertIn("IRINA_INSTALLED_USB_R1", prep)
        self.assertIn("hardware-profile.json", prep)
        self.assertIn("linux", read("hardware/acer_swift3_sf314-41.json"))
        self.assertIn("irina-grow-root.service", prep)
        self.assertIn("irina-auto-provision.timer", prep)
        self.assertIn("irina_setup_status.py", prep)
        self.assertIn("update-initramfs -u -k all", prep)

    def test_resize_target_is_mounted_external_root_only(self):
        grow = read("scripts/irina_grow_usb_root.sh")
        for expected in ("findmnt -n -o SOURCE /", "blkid -s LABEL", "IRINA_ROOT",
                         "lsblk -dn -o TRAN", "== usb", "IRINA_INSTALLED_USB_R1",
                         '== 2', "sgdisk -e", 'growpart "$DISK" 2',
                         'resize2fs "$ROOT"', "230000000000", "275000000000"):
            with self.subTest(expected=expected):
                self.assertIn(expected, grow)
        self.assertNotIn("diskpart", grow)
        self.assertNotIn("mkfs.", grow)
        self.assertNotIn("/dev/nvme0n1p", grow)
        self.assertNotIn("dd if=", grow)

    def test_apps_install_in_background_with_wifi_retry(self):
        apps = read("scripts/irina_auto_provision.sh")
        prep = read("scripts/prepare_installed_source.sh")
        self.assertIn("getent ahostsv4 archive.ubuntu.com", apps)
        self.assertIn("apt-get -y --no-install-recommends", apps)
        self.assertIn("libreoffice-writer", apps)
        self.assertIn("thunderbird", apps)
        self.assertIn("software-ready", apps)
        self.assertIn("OnUnitInactiveSec=10min", prep)
        self.assertNotIn("grub-install", apps)
        self.assertNotIn("sgdisk", apps)
        self.assertNotIn("growpart", apps)

    def test_previous_live_variants_stay(self):
        self.assertIn("mksquashfs", read("scripts/bake_image.sh"))
        self.assertIn("mksquashfs", read("scripts/bake_image_secureboot.sh"))
        self.assertIn("boot=casper", read("scripts/bake_image_secureboot.sh"))
        self.assertIn("irina_baikal_1.0_r2_secureboot.img",
                      read(".github/workflows/build-secureboot-img.yml"))


if __name__ == "__main__":
    unittest.main()
