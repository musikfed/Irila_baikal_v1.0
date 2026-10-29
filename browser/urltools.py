"""URL/address-bar handling, with no Qt dependency."""
import re
from urllib.parse import quote_plus, urlsplit

HOST = re.compile(r"^(?:localhost|(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}|\d{1,3}(?:\.\d{1,3}){3})(?::\d{1,5})?(?:[/?#]\S*)?$")

def address_to_url(text: str) -> str:
    raw = text.strip()
    if not raw:
        return "irina://home"
    parsed = urlsplit(raw)
    if parsed.scheme in ("http", "https") and parsed.netloc:
        return raw
    if HOST.fullmatch(raw):
        scheme = "http" if raw.startswith(("localhost", "127.0.0.1")) else "https"
        return f"{scheme}://{raw}"
    return "https://duckduckgo.com/?q=" + quote_plus(raw)
