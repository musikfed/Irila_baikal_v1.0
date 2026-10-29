#!/usr/bin/env python3
"""Local-only server for the Irina Baikal desktop prototype.

Run from Windows or Linux: python irina_shell.py
Open localhost on a randomly allocated port, never exposes files outside ./web.
AI requests are proxied to a local Ollama daemon (optional).
"""
import json
import os
import pathlib
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

WEB_ROOT = pathlib.Path(__file__).resolve().parent / "web"
OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
MODEL = os.environ.get("IRINA_MODEL", "qwen3:1.7b")

# Explicit allowlist. No shell command or user-provided arguments are accepted.
# Launchers work ONLY in an interactive, unprivileged Linux desktop session.
APP_COMMANDS = {
    "writer": ("libreoffice", "--writer"),
    "calc": ("libreoffice", "--calc"),
    "impress": ("libreoffice", "--impress"),
    "draw": ("libreoffice", "--draw"),
    "base": ("libreoffice", "--base"),
    "gimp": ("gimp",),
    "inkscape": ("inkscape",),
    "mail": ("thunderbird",),
    "sip": ("linphone",),
    "solitaire": ("sol", "aisleriot"),
    "mines": ("gnome-mines",),
    "mahjongg": ("gnome-mahjongg",),
}



class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_ROOT), **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Content-Security-Policy", "default-src 'self' data: blob:; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' blob: data:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'")
        super().end_headers()

    def _json(self, code, obj):
        payload = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def _launch(self):
        # This endpoint must not accept browser cross-site form posts.
        host = self.headers.get("Host", "")
        permitted = {
            f"127.0.0.1:{self.server.server_port}",
            f"localhost:{self.server.server_port}",
        }
        origin = self.headers.get("Origin", "")
        if host not in permitted or origin != "http://" + host:
            return self._json(403, {"error": "Same-origin local UI required"})
        if self.headers.get("Content-Type", "").split(";")[0] != "application/json":
            return self._json(415, {"error": "JSON request required"})
        if sys.platform != "linux" or os.geteuid() == 0:
            return self._json(409, {"error": "Native programs launch only from an unprivileged Linux desktop session"})
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size < 256:
                return self._json(413, {"error": "Invalid request size"})
            value = json.loads(self.rfile.read(size))
            app = value.get("app") if isinstance(value, dict) else None
            if not isinstance(app, str) or app not in APP_COMMANDS:
                return self._json(400, {"error": "Unknown application"})
            cmd = APP_COMMANDS[app]
            # Ubuntu's classic solitaire executable is often 'sol'.
            binary = shutil.which(cmd[0])
            command = cmd
            if app == "solitaire" and not binary:
                binary = shutil.which("aisleriot")
                command = ("aisleriot",)
            if not binary:
                return self._json(404, {"error": "Application is not installed in Linux"})
            subprocess.Popen(
                [binary, *command[1:]],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            return self._json(200, {"launched": app})
        except (ValueError, TypeError, json.JSONDecodeError):
            return self._json(400, {"error": "Invalid JSON"})
        except OSError:
            return self._json(502, {"error": "Could not start the application"})

    def do_POST(self):
        if self.path == "/api/launch":
            return self._launch()
        if self.path != "/api/ai":
            return self._json(404, {"error": "Unknown endpoint"})
        # Bind to loopback and reject requests from untrusted websites.
        host = self.headers.get("Host", "").split(":")[0].lower()
        origin = self.headers.get("Origin", "")
        if host not in ("127.0.0.1", "localhost") or (origin and origin != "http://" + self.headers.get("Host", "")):
            return self._json(403, {"error": "Only local UI may call this endpoint"})
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 12000:
                return self._json(413, {"error": "Message too large or missing"})
            obj = json.loads(self.rfile.read(size))
            message = obj.get("message", "")
            if not isinstance(message, str) or not 0 < len(message) <= 4000:
                return self._json(400, {"error": "Message must be 1–4000 characters"})
            body = json.dumps({"model": MODEL, "prompt": message, "stream": False, "options": {"num_predict": 380}}).encode("utf-8")
            req = urllib.request.Request(OLLAMA_URL, data=body, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=80) as res:
                reply = json.load(res).get("response", "")
            return self._json(200, {"reply": reply})
        except (urllib.error.URLError, TimeoutError, OSError):
            return self._json(503, {"error": "Ollama is not running locally at 127.0.0.1:11434"})
        except (json.JSONDecodeError, UnicodeDecodeError, ValueError):
            return self._json(400, {"error": "Invalid JSON request or Ollama response"})
        except Exception:
            return self._json(502, {"error": "Local model returned an unexpected error"})


if __name__ == "__main__":
    if not WEB_ROOT.is_dir():
        raise SystemExit(f"Web UI folder not found: {WEB_ROOT}")
    with ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
        url = f"http://127.0.0.1:{server.server_port}/"
        print("Ирина Байкал · оболочка прототип", url, flush=True)
        print("Нажми Ctrl+C для остановки. Не закрывай это окно во время работы интерфейса.", flush=True)
        webbrowser.open(url)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nОстановка интерфейса")
