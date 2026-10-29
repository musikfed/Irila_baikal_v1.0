"""Regression tests for the local Irina Shell Linux app launcher."""
import json
import sys
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from http.server import ThreadingHTTPServer

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from irina_shell import APP_COMMANDS, Handler


class LauncherSecurityTests(unittest.TestCase):
    def test_allowlist_does_not_contain_shells(self):
        self.assertNotIn("bash", APP_COMMANDS)
        self.assertNotIn("cmd", APP_COMMANDS)
        self.assertNotIn("python", APP_COMMANDS)
        for command in APP_COMMANDS.values():
            self.assertIsInstance(command, tuple)
            self.assertTrue(command)
            self.assertFalse(any("/" in piece or "\\x00" in piece for piece in command))

    def _deny_request(self, origin=None):
        with ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
            worker = threading.Thread(target=server.serve_forever, daemon=True)
            worker.start()
            url = f"http://127.0.0.1:{server.server_port}/api/launch"
            headers = {"Content-Type": "application/json"}
            if origin is not None:
                headers["Origin"] = origin
            req = urllib.request.Request(
                url, data=json.dumps({"app": "writer"}).encode("utf-8"),
                headers=headers, method="POST",
            )
            try:
                with self.assertRaises(urllib.error.HTTPError) as error:
                    urllib.request.urlopen(req, timeout=4)
                self.assertEqual(error.exception.code, 403)
            finally:
                server.shutdown()
                worker.join(timeout=4)

    def test_rejects_cross_origin(self):
        self._deny_request(origin="https://untrusted.example")

    def test_rejects_missing_origin(self):
        self._deny_request()


if __name__ == "__main__":
    unittest.main()
