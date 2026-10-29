#!/usr/bin/env python3
"""Static no-hardware regression checks for first Acer boot follow-up."""
import ast
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text("utf-8")


class EvidenceAndFullCI(unittest.TestCase):
    def test_gallery_safe_publishing(self):
        code = read("scripts/build_first_boot_gallery.py")
        ast.parse(code)
        self.assertIn("len(written) != len(IMAGES)", code)
        self.assertIn("18", read("docs/first_boot/README.md"))
        self.assertIn("ImageOps.exif_transpose", code)
        self.assertIn("photo.save(", code)
        self.assertNotIn(".extractall(", code)
        self.assertIn("re.fullmatch(", code)
        self.assertIn("source.width", code)
        wf = read(".github/workflows/publish-first-boot-gallery.yml")
        self.assertIn("photos-source.zip", wf)
        self.assertIn("build_first_boot_gallery.py", wf)

    def test_full_image_is_distinct(self):
        wf = read(".github/workflows/build-installed-full-secureboot-img.yml")
        self.assertIn("irina_baikal_1.0_full_installed_secureboot.img", wf)
        self.assertIn("irina-baikal-1.0-full-installed-secureboot-img", wf)
        self.assertIn("IMG_PROFILE: ${{ inputs.profile || 'full' }}", wf)
        self.assertIn("linphone-desktop", wf)
        self.assertIn("linux-firmware", wf)
        self.assertIn("dpkg-query -W", wf)
        self.assertIn("installed-packages.txt", wf)
        self.assertNotIn("irina-baikal-1.0-installed-secureboot-img\n", wf)

    def test_first_boot_hardware_evidence(self):
        doc = read("docs/first_boot/README.md")
        self.assertIn("235 ГиБ", doc)
        self.assertIn("xfwm4", doc)
        self.assertIn("Invalid constraint", doc)
        self.assertIn("Thunderbird", doc)
        self.assertIn("Rufus START", doc)

    def test_lake_audio_and_camera_fallback(self):
        audio = read("audio/generate_intro.py")
        ast.parse(audio)
        self.assertIn("def lake_background", audio)
        self.assertIn("Создана за пять часов", audio)
        self.assertIn("choices=('lake', 'cosmic')", audio)
        js = read("ui/web/app.js")
        self.assertIn("OverconstrainedError", js)
        self.assertIn("getUserMedia({video:true,audio:false})", js)

if __name__ == "__main__":
    unittest.main()
