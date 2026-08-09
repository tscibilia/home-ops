#!/usr/bin/env python3
"""
Minimal aKeyless auth proxy for doco-cd webhook provider.

Handles the two-step aKeyless auth flow:
1. POST /auth -> get token
2. POST /get-secret-value with token -> get secret

Exposes a single HTTP endpoint for doco-cd's webhook provider to call.
"""

import json
import os
import sys
import threading
import time
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import urllib.request
import urllib.error

# Secret values are cached for 5 minutes; token for 50 minutes.
_SECRET_TTL = 300
_TOKEN_TTL = 3000


class _Server(ThreadingHTTPServer):
    # Python's default backlog is 5. doco-cd bursts 20-40 secret fetches in a
    # second during a deploy, overflowing the listen queue so the kernel RSTs
    # the excess and the deployment fails on "connection reset by peer".
    request_queue_size = 128


class AKeylessProxy(BaseHTTPRequestHandler):
    """HTTP handler for aKeyless secret proxy."""

    # Keep-alive: doco-cd fetches ~20 secrets per deploy and opens a new
    # connection for each without it. Requires Content-Length on every
    # response — see _send. timeout stops idle connections holding threads.
    protocol_version = "HTTP/1.1"
    timeout = 30

    access_id = os.getenv("AKEYLESS_ACCESS_ID")
    access_key = os.getenv("AKEYLESS_ACCESS_KEY")
    api_url = "https://api.akeyless.io"

    _token = None
    _token_expiry = 0.0
    _token_lock = threading.Lock()

    _secret_cache: dict = {}
    _secret_lock = threading.Lock()

    @classmethod
    def _get_token(cls) -> str:
        with cls._token_lock:
            if cls._token and time.monotonic() < cls._token_expiry:
                return cls._token
            auth_payload = {
                "access-id": cls.access_id,
                "access-key": cls.access_key,
                "access-type": "access_key",
            }
            req = urllib.request.Request(
                f"{cls.api_url}/auth",
                data=json.dumps(auth_payload).encode(),
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(req) as resp:
                data = json.loads(resp.read())
            token = data.get("token")
            if not token:
                raise ValueError("No token in auth response")
            cls._token = token
            cls._token_expiry = time.monotonic() + _TOKEN_TTL
            return token

    @classmethod
    def _fetch_secret(cls, name: str) -> dict:
        with cls._secret_lock:
            entry = cls._secret_cache.get(name)
            if entry and time.monotonic() < entry[1]:
                return entry[0]

        token = cls._get_token()
        req = urllib.request.Request(
            f"{cls.api_url}/get-secret-value",
            data=json.dumps({"names": [name], "token": token}).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read())

        with cls._secret_lock:
            cls._secret_cache[name] = (data, time.monotonic() + _SECRET_TTL)
        return data

    def _send(self, code: int, body: bytes, ctype: str = "application/json"):
        """Send a response. Content-Length is mandatory under HTTP/1.1."""
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed_url = urlparse(self.path)

        if parsed_url.path != "/secret":
            self._send(404, b'{"error": "not found"}')
            return

        query_params = parse_qs(parsed_url.query)
        secret_name = query_params.get("name", [None])[0]

        if not secret_name:
            self._send(400, b'{"error": "missing name query parameter"}')
            return

        try:
            secret_data = self._fetch_secret(secret_name)
            self._send(200, json.dumps(secret_data).encode())
        except urllib.error.HTTPError as e:
            self._send(e.code, e.read())
        except Exception as e:
            self._send(500, json.dumps({"error": str(e)}).encode())

    def log_message(self, format, *args):
        sys.stdout.write(f"[{self.log_date_time_string()}] {format % args}\n")
        sys.stdout.flush()


if __name__ == "__main__":
    access_id = os.getenv("AKEYLESS_ACCESS_ID")
    access_id_file = os.getenv("AKEYLESS_ACCESS_ID_FILE")
    if access_id_file and not access_id:
        with open(access_id_file) as f:
            access_id = f.read().strip()

    access_key = os.getenv("AKEYLESS_ACCESS_KEY")
    access_key_file = os.getenv("AKEYLESS_ACCESS_KEY_FILE")
    if access_key_file and not access_key:
        with open(access_key_file) as f:
            access_key = f.read().strip()

    if not access_id or not access_key:
        print(
            "Error: AKEYLESS_ACCESS_ID and AKEYLESS_ACCESS_KEY must be set (or their _FILE variants)",
            file=sys.stderr,
        )
        sys.exit(1)

    AKeylessProxy.access_id = access_id
    AKeylessProxy.access_key = access_key

    server = _Server(("0.0.0.0", 8080), AKeylessProxy)
    print("aKeyless proxy listening on http://0.0.0.0:8080", file=sys.stderr)
    server.serve_forever()
