"""Run: python3 -m unittest discover -s ui/tests -v"""
import http.client
import importlib.util
import json
import pathlib
import threading
import unittest
from http.server import ThreadingHTTPServer

MOD_FILE = pathlib.Path(__file__).resolve().parents[1] / 'irina_shell.py'
spec = importlib.util.spec_from_file_location('irina_shell', MOD_FILE)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class ShellServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(('127.0.0.1', 0), mod.Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def request(self, method, path, data=None, headers=None):
        conn = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=3)
        conn.request(method, path, body=data, headers=headers or {})
        res = conn.getresponse()
        body = res.read()
        conn.close()
        return res.status, body, dict(res.getheaders())

    def test_homepage(self):
        code, body, headers = self.request('GET', '/')
        self.assertEqual(code, 200)
        self.assertIn('Ирина Байкал'.encode(), body)
        self.assertEqual(headers['X-Frame-Options'], 'DENY')

    def test_ai_wrong_endpoint(self):
        code, _, _ = self.request('POST', '/api/nonexistent', b'{}')
        self.assertEqual(code, 404)

    def test_ai_bad_origin(self):
        code, _, _ = self.request('POST', '/api/ai', b'{}', {'Origin': 'https://unknown.example'})
        self.assertEqual(code, 403)

    def test_ai_wrong_local_origin_port(self):
        code, _, _ = self.request('POST', '/api/ai', b'{}', {'Origin': 'http://127.0.0.1:9999'})
        self.assertEqual(code, 403)

    def test_ai_bad_body(self):
        code, _, _ = self.request('POST', '/api/ai', b'no', {'Content-Type': 'application/json'})
        self.assertEqual(code, 400)

    def test_ai_oversized(self):
        code, _, _ = self.request('POST', '/api/ai', b'x' * 12001)
        self.assertEqual(code, 413)


if __name__ == '__main__':
    unittest.main()
