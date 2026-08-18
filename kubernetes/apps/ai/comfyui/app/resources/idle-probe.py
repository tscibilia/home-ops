#!/usr/bin/env python3
"""Idle signal and wake responder for LLMKube's ModelPool.

/healthz                   200 once ComfyUI answers        -> readiness
/idle                      200 only when its queue is empty -> safe to unload
/metrics                   queue depth; the llmkube-models ServiceMonitor
                           scrapes this port, so 404 here means TargetDown
GET  /v1/models            advertises this pod as a model
POST /v1/chat/completions  answers the wake request

The wake path exists because the activator only fires on an OpenAI-shaped
request; by the time it runs the swap is done, so it just returns the URL.

Fail-closed: any error on /idle reports busy, so a swap is never granted
over a render the probe could not see.
"""

import json
import os
import time
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

COMFYUI = "http://127.0.0.1:8188"
TIMEOUT = 5
PORT = 9000
MODEL_ID = "comfyui"
UI_URL = f"https://{os.environ.get('COMFYUI_URL', 'comfyui')}"


def queued():
    """Running + pending prompts. /queue counts both; /prompt only reports pending."""
    with urllib.request.urlopen(f"{COMFYUI}/queue", timeout=TIMEOUT) as response:
        queue = json.load(response)
    return len(queue.get("queue_running", [])) + len(queue.get("queue_pending", []))


def wake_message():
    try:
        depth = queued()
    except Exception as err:  # noqa: BLE001 - readiness gates this, so it should not happen
        return f"ComfyUI holds the GPU but is not answering yet: {err}"
    busy = f" It has {depth} job(s) queued." if depth else ""
    return f"ComfyUI is awake and holds the GPU. Open {UI_URL}.{busy}"


class Probe(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):  # noqa: N802 - BaseHTTPRequestHandler's own naming
        if self.path.startswith("/healthz"):
            self.reply(*self.healthz())
        elif self.path.startswith("/idle"):
            self.reply(*self.idle())
        elif self.path.startswith("/metrics"):
            self.reply(200, self.metrics())
        elif self.path.startswith("/v1/models"):
            self.reply_json(200, {
                "object": "list",
                "data": [{"id": MODEL_ID, "object": "model", "owned_by": "llmkube"}],
            })
        else:
            self.reply(404, "not found")

    def do_POST(self):  # noqa: N802
        if not self.path.startswith("/v1/chat/completions"):
            self.reply(404, "not found")
            return

        length = int(self.headers.get("Content-Length") or 0)
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            body = {}

        if body.get("stream"):
            self.reply_stream(wake_message())
        else:
            self.reply_json(200, self.completion(wake_message()))

    def healthz(self):
        try:
            queued()
        except Exception as err:  # noqa: BLE001 - any failure means not serving yet
            return 503, f"comfyui unreachable: {err}"
        return 200, "ok"

    def idle(self):
        try:
            depth = queued()
        except Exception as err:  # noqa: BLE001 - unknown state counts as busy
            return 503, f"busy (idle unknown): {err}"
        return (200, "idle") if depth == 0 else (503, f"busy: {depth} queued")

    def metrics(self):
        try:
            depth = queued()
        except Exception:  # noqa: BLE001 - unreachable ComfyUI is reported, not hidden
            up, depth = 0, 0
        else:
            up = 1
        return (
            "# HELP comfyui_up ComfyUI answers its HTTP API.\n"
            "# TYPE comfyui_up gauge\n"
            f"comfyui_up {up}\n"
            "# HELP comfyui_queue_depth Running plus pending prompts; the pool "
            "defers a swap until this reaches zero.\n"
            "# TYPE comfyui_queue_depth gauge\n"
            f"comfyui_queue_depth {depth}\n"
        )

    def completion(self, text):
        return {
            "id": f"chatcmpl-{uuid.uuid4().hex}",
            "object": "chat.completion",
            "created": int(time.time()),
            "model": MODEL_ID,
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": text},
                "finish_reason": "stop",
            }],
            "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
        }

    def reply(self, status, body):
        payload = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def reply_json(self, status, obj):
        payload = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def reply_stream(self, text):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        # No Content-Length on a stream, so HTTP/1.1 needs the close to frame it.
        self.send_header("Connection", "close")
        self.close_connection = True
        self.end_headers()
        base = {
            "id": f"chatcmpl-{uuid.uuid4().hex}",
            "object": "chat.completion.chunk",
            "created": int(time.time()),
            "model": MODEL_ID,
        }
        for delta, finish in (({"role": "assistant", "content": text}, None), ({}, "stop")):
            chunk = dict(base, choices=[{"index": 0, "delta": delta, "finish_reason": finish}])
            self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
        self.wfile.write(b"data: [DONE]\n\n")

    def log_message(self, *_args):
        pass  # probed every few seconds; silence keeps the pod log usable


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Probe).serve_forever()
