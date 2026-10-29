#!/usr/bin/env python3
"""Static and checksum-transfer regressions for experimental Irina image pipeline.

Does not require root, touch physical disks or build a real image.
Run: python3 -m unittest discover -s tests -p 'test_readonly_pipeline.py' -v
"""
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class TestReadOnlyPipeline(unittest.TestCase):
    def test_linux_script_syntax(self):
        for name in ("prepare_source.sh", "bake_image.sh",
                     "build_in_wsl.sh", "check_wsl_loop.sh"):
            file = REPO / "scripts" / name
            with self.subTest(script=name):
                subprocess.run(["bash", "-n", str(file)], check=True)

    def test_powershell_embedded_scripts_bash_syntax(self):
        for name in ("Build-IrinaViaWSL.ps1", "Build-IrinaViaWSL-v2.ps1"):
            script = (REPO / "windows" / name).read_text(encoding="utf-8")
            with self.subTest(script=name):
                self.assertIn("--exec /bin/bash $linuxFile", script)
                self.assertNotIn("-- bash -lc $preflight", script)
                self.assertNotIn("-- bash -lc $commands", script)
                for key in ("preflight", "commands"):
                    pattern = r"\$" + key + r"=@'\n(.*?)\n'@"
                    match = re.search(pattern, script, re.S)
                    self.assertIsNotNone(match, key)
                    body = match.group(1).replace("__PROFILE__", "core").replace("__MAX__", "5120")
                    subprocess.run(["bash", "-n"], input=body, text=True, check=True)
        latest = (REPO / "windows" / "Build-IrinaViaWSL-v2.ps1").read_text("utf-8")
        self.assertIn("IRINA WSL BUILDER v2.3", latest)
        self.assertIn("--exec /bin/bash $linuxFile | Out-Host", latest)
        self.assertIn("$exitCode = [int]$LASTEXITCODE", latest)
        self.assertIn("CHECK-ONLY PASS", latest)
        self.assertIn("udev mount grub-efi-amd64-bin", latest)

    def test_checksum_after_copy_checks_copy_not_source(self):
        script = (REPO / "scripts" / "bake_image.sh").read_text(encoding="utf-8")
        self.assertNotIn('sha256sum "$OUT" > "$OUT.sha256"', script)
        # Execute the actual manifest-generation block from the production script
        # with a tiny fixture and without running the rest of image creation.
        match = re.search(
            r'(# CRITICAL: hash manifest.*?)(\n\(\n  cd "\$\(dirname "\$OUT"\)"\n.*?\n\))'
            r'\n# Let the ordinary Windows/WSL user', script, re.S
        )
        self.assertIsNotNone(match, "Production manifest generation block not found")
        block = match.group(2)
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            original = root / "rootfs" / "irina_baikal_1.0.img"
            original.parent.mkdir()
            original.write_bytes(b"expected image bytes")
            subprocess.run(["bash", "-euc", block], env={"OUT": str(original), "PATH": "/usr/bin:/bin"}, check=True, capture_output=True)
            manifest = original.with_name(original.name + ".sha256")
            self.assertEqual(manifest.read_text().strip(),
                             hashlib.sha256(original.read_bytes()).hexdigest() + "  " + original.name)
            target = root / "F-copy"
            target.mkdir()
            shutil.copy2(original, target)
            shutil.copy2(manifest, target)
            # Corrupt ORIGINAL: copied image still verifies if path is relative.
            original.write_bytes(b"corrupted original")
            subprocess.run(["sha256sum", "-c", manifest.name], cwd=target, check=True, capture_output=True)
            # Corrupt COPIED image: verification must FAIL even when original exists.
            (target / original.name).write_bytes(b"corrupted copy")
            check = subprocess.run(["sha256sum", "-c", manifest.name], cwd=target, capture_output=True)
            self.assertNotEqual(check.returncode, 0)

    def test_bake_uses_only_new_image_file(self):
        script = (REPO / "scripts" / "bake_image.sh").read_text("utf-8")
        self.assertIn('losetup --find --show --partscan "$OUT"', script)
        self.assertIn('[[ ! -e "$OUT" && ! -L "$OUT" ]]', script)
        self.assertIn('partx --update "$LOOP"', script)
        self.assertIn('[[ -b "$EFI" && -b "$LIVE" ]]', script)
        self.assertIn("BOOTX64.EFI", script)
        self.assertIn("boot=casper nopersistent", script)

    def test_copy_refuses_existing_artifacts(self):
        script = (REPO / "scripts" / "build_in_wsl.sh").read_text("utf-8")
        self.assertIn('[[ ! -e "$DEST/irina_baikal_1.0.img" ]]', script)
        self.assertIn('cp --no-clobber', script)
        self.assertIn('sha256sum -c irina_baikal_1.0.img.sha256', script)


if __name__ == "__main__":
    unittest.main()
