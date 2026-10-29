#!/usr/bin/env python3
"""Irina Baikal image preflight (Windows 11) and optional guarded Linux dd writer.

Windows: py -3.13 scripts/flash_irina.py --image C:\path\irina_baikal_1.0.img
After the check, open Rufus and manually choose the verified external USB SSD.
Linux: sudo python3 scripts/flash_irina.py --image ... --write-linux /dev/sdX
NO Windows raw disk writes are performed by this program.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

MIN_TARGET_GB = 230
MAX_TARGET_GB = 270


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def verify_checksum(image):
    expected_file = Path(str(image) + ".sha256")
    if not expected_file.is_file():
        raise RuntimeError("No .sha256 next to image; refuse to flash unverified image")
    content = expected_file.read_text(encoding="utf-8").strip().split()
    if not content or len(content[0]) != 64 or not all(c in "0123456789abcdefABCDEF" for c in content[0]):
        raise RuntimeError("Invalid SHA256 file")
    digest = sha256(image)
    if digest.lower() != content[0].lower():
        raise RuntimeError(f"SHA256 MISMATCH! expected {content[0]}, got {digest}")
    return digest


def list_windows_disks():
    script = (
        "Get-Disk | Select-Object Number,FriendlyName,BusType,Size,IsBoot,IsSystem,"
        "OperationalStatus | ConvertTo-Json -Depth 4 -Compress"
    )
    p = subprocess.run(
        ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
        capture_output=True, text=True, check=True
    )
    data = json.loads(p.stdout)
    return [data] if isinstance(data, dict) else data


def windows_preflight():
    disks = list_windows_disks()
    print("\nWindows disks (READ-ONLY INSPECTION; NOTHING IS WRITTEN):")
    for d in disks:
        gb = int(d["Size"]) / 1e9
        candidate = (
            str(d.get("BusType", "")).lower() == "usb"
            and MIN_TARGET_GB <= gb <= MAX_TARGET_GB
            and not d.get("IsBoot") and not d.get("IsSystem")
        )
        print(f'  #{d.get("Number")} {d.get("FriendlyName")!s:28} '
              f'{gb:6.1f} GB   bus={d.get("BusType")} '
              f'boot={d.get("IsBoot")} system={d.get("IsSystem")} '
              f'{"POSSIBLE EXTERNAL SSD" if candidate else "DO NOT AUTO-SELECT"}')
    print("\nIdentify the actual 256GB USB SSD by MODEL + SIZE + physically unplug/replug.")
    print("Do not touch the internal Windows 512GB SSD. Open https://rufus.ie/")
    print("Choose the IMG and external target manually; use DD/raw if asked.")
    print("Never pre-format a target when writing a complete GPT image.")


def linux_preflight(device):
    if os.geteuid() != 0:
        raise RuntimeError("Linux raw writing requires sudo")
    data = json.loads(subprocess.check_output(
        ["lsblk", "--json", "-b", "-o",
         "NAME,PATH,SIZE,MODEL,TRAN,TYPE,MOUNTPOINTS,RO", "-e", "7"],
        text=True
    ))
    matches = [x for x in data["blockdevices"] if x.get("path") == device]
    if len(matches) != 1:
        raise RuntimeError("Target must be an exact whole-disk path from lsblk")
    disk = matches[0]
    if disk.get("type") != "disk" or disk.get("tran") != "usb" or disk.get("ro"):
        raise RuntimeError("Refusing target that is not writable USB whole disk")
    if not MIN_TARGET_GB <= disk["size"] / 1e9 <= MAX_TARGET_GB:
        raise RuntimeError("USB disk is not in the expected 256 GB capacity range")
    def all_parts(node):
        yield node
        for child in node.get("children") or []:
            yield from all_parts(child)
    if any(node.get("mountpoints") and any(node["mountpoints"]) for node in all_parts(disk)):
        raise RuntimeError("USB disk has mounted filesystem(s); refusing to write")
    return disk


def linux_flash(device, image):
    disk = linux_preflight(device)
    print(f'ATTENTION: dd will erase ALL DATA on {device} ({disk.get("model")}, '
          f'{disk["size"]/1e9:.1f} GB, USB).')
    print("Disconnect the Windows internal disk from the write operation.")
    phrase = f"ERASE {device}"
    if input(f"To write, enter exactly '{phrase}': ").strip() != phrase:
        raise RuntimeError("Cancelled")
    subprocess.run([
        "dd", f"if={str(image)}", f"of={device}",
        "bs=4M", "status=progress", "conv=fsync"
    ], check=True)
    subprocess.run(["sync"], check=True)
    print("Flashing completed. Safely unplug SSD; boot Acer via F12.")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--image", required=True, type=Path)
    p.add_argument("--write-linux", metavar="/dev/sdX",
                   help="Linux-only, guarded, DESTRUCTIVE raw write")
    args = p.parse_args()
    image = args.image.resolve(strict=True)
    if not image.is_file() or image.suffix.lower() != ".img":
        p.error("Must be existing regular IMG")
    if Path(str(image) + ".FAILED").exists():
        p.error("FAILED marker exists. Incomplete build MUST NOT be flashed.")
    print("Verifying SHA256 (whole image) ...")
    print("Verified:", verify_checksum(image))
    if sys.platform == "win32":
        if args.write_linux:
            p.error("Windows raw disk writing disabled. Use Rufus.")
        windows_preflight()
    elif sys.platform.startswith("linux"):
        if args.write_linux:
            linux_flash(args.write_linux, image)
        else:
            print("Linux preflight done. To flash, use --write-linux /dev/<VERIFIED_USB_DISK>.")
    else:
        p.error("Unsupported platform")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"IRINA FLASH ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
