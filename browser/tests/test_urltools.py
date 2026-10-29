import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from urltools import address_to_url

class TestAddressBar(unittest.TestCase):
    def test_domain(self):
        self.assertEqual(address_to_url("example.com"), "https://example.com")
    def test_url(self):
        self.assertEqual(address_to_url("https://example.com/path"), "https://example.com/path")
    def test_localhost(self):
        self.assertEqual(address_to_url("localhost:8000"), "http://localhost:8000")
    def test_search(self):
        self.assertEqual(address_to_url("озеро байкал"), "https://duckduckgo.com/?q=%D0%BE%D0%B7%D0%B5%D1%80%D0%BE+%D0%B1%D0%B0%D0%B9%D0%BA%D0%B0%D0%BB")
    def test_reject_javascript(self):
        self.assertTrue(address_to_url("javascript:alert(1)").startswith("https://duckduckgo.com/"))
    def test_empty(self):
        self.assertEqual(address_to_url("  "), "irina://home")

if __name__ == "__main__":
    unittest.main()
