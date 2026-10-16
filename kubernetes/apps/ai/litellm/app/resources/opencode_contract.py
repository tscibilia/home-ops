"""Make litellm-proxied requests satisfy opencode Zen's free-tier client gate.

Zen's edge answers 403 FreeTierError to anything that does not look like the
official CLI. Three things are actually checked (measured 2026-10-16, CLI
2.0.31):

  * the request body streams,
  * the body carries a tool named exactly ``read``,
  * ``x-opencode-session`` is shaped by opencode's own identifier algorithm.

Transport, TLS fingerprint, Bun version, tool schemas and the other
``x-opencode-*`` headers are not checked, and the session id has no freshness
window, so the id is minted per request only to keep requests from sharing one.
"""

from __future__ import annotations

import os
import time

from litellm.integrations.custom_logger import CustomLogger

# opencode's identifier alphabet (packages/schema/src/identifier.ts).
_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

# Appended only when the caller sent no tool named `read`, so a client's own
# toolset reaches the model unchanged. The gate ignores this schema. The two
# APIs carry the same tool in different shapes: chat completions nests name and
# parameters under `function`, the Responses API puts them beside `type`.
_READ_TOOL_CHAT = {
    "type": "function",
    "function": {
        "name": "read",
        "description": "Read a file from the working directory.",
        "parameters": {
            "type": "object",
            "properties": {"path": {"type": "string"}},
            "required": ["path"],
        },
    },
}

_READ_TOOL_RESPONSES = {
    "type": "function",
    "name": "read",
    "description": "Read a file from the working directory.",
    "parameters": {
        "type": "object",
        "properties": {"path": {"type": "string"}},
        "required": ["path"],
    },
}

_last_ms = 0
_counter = 0


def _session_id(ms: int | None = None, invert: bool = True) -> str:
    """opencode's Session.ID: hex48(~(ms * 4096 + counter)) + 14 base62 chars.

    ``invert`` distinguishes the session variant from the permission variant;
    the edge rejects a session id built from the non-inverted value.
    """
    global _last_ms, _counter
    if ms is None:
        ms = int(time.time() * 1000)
    if ms != _last_ms:
        _last_ms, _counter = ms, 0
    _counter += 1
    value = ms * 0x1000 + _counter
    if invert:
        value = ~value
    hex_part = "".join(f"{(value >> (40 - 8 * i)) & 0xFF:02x}" for i in range(6))
    random_part = "".join(_ALPHABET[byte % 62] for byte in os.urandom(14))
    return f"ses_{hex_part}{random_part}"


def _gated(model: str | None) -> bool:
    configured = os.environ.get("OPENCODE_FREE_MODELS", "")
    return bool(model) and model in {name.strip() for name in configured.split(",") if name.strip()}


# 1.105.1 hands the hook "acompletion" for /v1/chat/completions and "aresponses"
# for /v1/responses; the documented Literal uses the un-prefixed spellings.
# Accept both, and pick the tool shape that matches the API being called.
_CALL_TYPE_TOOLS = {
    "completion": _READ_TOOL_CHAT,
    "acompletion": _READ_TOOL_CHAT,
    "responses": _READ_TOOL_RESPONSES,
    "aresponses": _READ_TOOL_RESPONSES,
}


def _read_tool_for(call_type):
    return _CALL_TYPE_TOOLS.get(str(getattr(call_type, "value", call_type)))


def _tool_name(tool):
    """Tool name in either shape: chat completions nests it under `function`."""
    if not isinstance(tool, dict):
        return None
    return tool.get("name") or (tool.get("function") or {}).get("name")


class OpenCodeContract(CustomLogger):
    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        stub = _read_tool_for(call_type)
        if stub is None or not _gated(data.get("model")):
            return data

        # Zen refuses a non-streaming body outright, so these models always
        # answer with SSE regardless of what the caller asked for.
        data["stream"] = True

        tools = data.get("tools")
        if not isinstance(tools, list):
            tools = []
        if not any(_tool_name(tool) == "read" for tool in tools):
            tools = [*tools, stub]
        data["tools"] = tools

        session = _session_id()
        data["extra_headers"] = {
            **(data.get("extra_headers") or {}),
            "User-Agent": "opencode/latest/2.0.31/cli",
            "x-opencode-client": "cli",
            "x-opencode-session": session,
            "x-opencode-session-id": session,
            "x-session-affinity": session,
            "x-session-id": session,
        }
        return data


opencode_contract = OpenCodeContract()
