"""Irina Baikal Hrag: local-only HTML-to-clean-text service, minimal version.

This is not a transparent HTTPS interceptor or an autonomous browsing agent.
Allowlist: IRINA_HRAG_ALLOWED_HOSTS=example.org,ru.wikipedia.org
"""
from __future__ import annotations

import ipaddress
import os
import socket
from urllib.parse import urlsplit

from bs4 import BeautifulSoup
from fastapi import FastAPI, HTTPException, Query
import requests

app = FastAPI(title="Ирина Байкал — Hrag", version="0.1")
MAX_HTML_BYTES = 1024 * 1024
ALLOWED = {x.strip().lower() for x in
           os.environ.get("IRINA_HRAG_ALLOWED_HOSTS", "ru.wikipedia.org,en.wikipedia.org").split(",")
           if x.strip()}


def validate(url: str):
    parts = urlsplit(url)
    if parts.scheme != "https" or not parts.hostname or parts.username or parts.password:
        raise HTTPException(400, "Only HTTPS links without credentials are allowed")
    host = parts.hostname.lower().rstrip(".")
    if host not in ALLOWED:
        raise HTTPException(403, "Host not on IRINA_HRAG_ALLOWED_HOSTS")
    if parts.port not in (None, 443):
        raise HTTPException(403, "Only standard HTTPS port 443 allowed")
    try:
        infos = socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)
        if not infos:
            raise ValueError("No addresses")
        for item in infos:
            addr = ipaddress.ip_address(item[4][0])
            if not addr.is_global:
                raise ValueError("Non-public network destination blocked")
    except (OSError, ValueError) as exc:
        raise HTTPException(400, f"Cannot safely resolve hostname: {exc}") from exc
    return host


@app.get("/health")
def health():
    return {"service": "irina-hrag", "status": "ok", "allowed_hosts": sorted(ALLOWED)}


@app.get("/clean")
def clean(url: str = Query(min_length=10, max_length=2048)):
    """Strip HTML scripts, styles, nav, forms, iframes, and return plain text.

    Requests are loopback-only at uvicorn process level. DNS rebinding is NOT
    fully mitigated in this prototype; only explicit trusted domain allowlist
    should be used and do not expose the service to the network.
    """
    validate(url)
    try:
        with requests.get(url, timeout=(5, 10), stream=True,
                          allow_redirects=False,
                          headers={"User-Agent": "IrinaBaikalHrag/0.1"}) as res:
            if 300 <= res.status_code < 400:
                raise HTTPException(400, "Redirects are disabled")
            res.raise_for_status()
            content_type = res.headers.get("Content-Type", "").lower()
            if "text/html" not in content_type:
                raise HTTPException(415, "URL did not return text/html")
            content = bytearray()
            for chunk in res.iter_content(chunk_size=32768):
                content.extend(chunk)
                if len(content) > MAX_HTML_BYTES:
                    raise HTTPException(413, "HTML document exceeds 1 MiB limit")
            html = bytes(content)
    except requests.RequestException as exc:
        raise HTTPException(502, f"Could not download page: {type(exc).__name__}") from exc
    soup = BeautifulSoup(html, "html.parser")
    for bad in soup(["script", "style", "iframe", "form", "nav",
                     "footer", "noscript", "svg", "button", "aside"]):
        bad.decompose()
    title = soup.title.get_text(" ", strip=True) if soup.title else ""
    body = soup.body if soup.body else soup
    text = " ".join(body.stripped_strings)
    text = text[:25000]
    return {"url": url, "title": title, "text": text, "characters": len(text)}
