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
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import urllib.request
import urllib.error


class AKeylessProxy(BaseHTTPRequestHandler):
    """HTTP handler for aKeyless secret proxy."""

    access_id = os.getenv("AKEYLESS_ACCESS_ID")
    access_key = os.getenv("AKEYLESS_ACCESS_KEY")
    api_url = "https://api.akeyless.io"

    def do_GET(self):
        """Handle GET /secret?name=path/to/secret"""
        parsed_url = urlparse(self.path)

        if parsed_url.path != "/secret":
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not found")
            return

        # Parse query string: ?name=path/to/secret
        query_params = parse_qs(parsed_url.query)
        secret_name = query_params.get("name", [None])[0]

        if not secret_name:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b'{"error": "missing name query parameter"}')
            return

        try:
            # Step 1: Get auth token
            auth_payload = {
                "access-id": self.access_id,
                "access-key": self.access_key,
                "access-type": "access_key",
            }
            auth_req = urllib.request.Request(
                f"{self.api_url}/auth",
                data=json.dumps(auth_payload).encode(),
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(auth_req) as auth_resp:
                auth_data = json.loads(auth_resp.read())
                token = auth_data.get("token")

            if not token:
                raise ValueError("No token in auth response")

            # Step 2: Get secret value
            secret_payload = {
                "names": [secret_name],
                "token": token,
            }
            secret_req = urllib.request.Request(
                f"{self.api_url}/get-secret-value",
                data=json.dumps(secret_payload).encode(),
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(secret_req) as secret_resp:
                secret_data = json.loads(secret_resp.read())

            # Return the response as-is for doco-cd's JMESPath to parse
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(secret_data).encode())

        except urllib.error.HTTPError as e:
            error_body = e.read().decode()
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(error_body.encode())
        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def log_message(self, format, *args):
        """Log to stdout instead of stderr."""
        sys.stdout.write(f"[{self.log_date_time_string()}] {format % args}\n")
        sys.stdout.flush()


if __name__ == "__main__":
    # Read from env vars or files
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
        print("Error: AKEYLESS_ACCESS_ID and AKEYLESS_ACCESS_KEY must be set (or their _FILE variants)", file=sys.stderr)
        sys.exit(1)

    AKeylessProxy.access_id = access_id
    AKeylessProxy.access_key = access_key

    server = HTTPServer(("0.0.0.0", 8080), AKeylessProxy)
    print(f"aKeyless proxy listening on http://0.0.0.0:8080", file=sys.stderr)
    server.serve_forever()
