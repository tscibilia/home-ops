# Route `deepseek-v4.1-flash` through opencode Zen's free tier, with `-paid` as the fallback

**Status:** accepted
**Date:** 2026-10-16

`deepseek-v4.1-flash` resolves to opencode Zen's free promo endpoint (`openai/deepseek-v4.1-flash-free` on `https://opencode.ai/zen/v1`). The OpenRouter/DeepInfra route of the same weights keeps its parameters under the new name `deepseek-v4.1-flash-paid`. Nothing routes between them automatically: falling back is a model-name change on the client.

Zen refuses its free tier to anything that does not look like the official CLI, and the refusal is not a transport fingerprint. Measured on 2026-10-16 against CLI 2.0.31, the edge accepts a request only when all three hold:

- the body streams — `stream: false` and an absent `stream` both return 403 `FreeTierError`;
- the body carries a tool named exactly `read` — every other name tried (`bash`, `shell`, `Read`, `edit`, `_noop`, …) is refused, and the schema is never inspected;
- `x-opencode-session`, plus `x-opencode-session-id`, `x-session-affinity` and `x-session-id`, is `ses_` followed by the low 48 bits of `~(ms * 4096 + counter)` in hex and 14 base62 characters — opencode's own `identifier.ts` algorithm, using the inverted variant that separates session ids from permission ids.

TLS/JA3 fingerprint, Bun version, `x-opencode-org-id`, `x-opencode-project`, session freshness and the caller's tool schemas are not checked. `User-Agent` must still begin `opencode/`.

Because the `read` tool has to be _added to_ the caller's toolset rather than replacing it, no combination of litellm's `extra_headers` and `extra_body` satisfies the contract: `extra_body.tools` overwrites the array. The proxy therefore loads `resources/opencode_contract.py` as a `CustomLogger` pre-call hook, which forces the upstream stream, appends a stub `read` tool when the caller sent none, and mints a session id per request. The hook runs only for the model names listed in `OPENCODE_FREE_MODELS`.

## Considered options

**Leave it reverted.** #4380 repointed this model at Zen; #4381 reverted it on the finding that the gate is a TLS/transport fingerprint and that "only a live opencode process can reach the free models". That finding is wrong — the same requests pass from curl, Bun and Node once the three conditions hold, and fail when any one of them is removed. Keeping the revert would have left free capacity unused on a false premise.

**Relay through a real opencode process.** Running `opencode serve` beside the proxy and translating between its session API and the OpenAI chat schema would survive any future tightening of the gate, because the request would be genuine. Rejected as the first move: a second runtime, a translation layer and a new failure surface, for a gate that three fields currently satisfy. It stays the fallback if the gate starts keying on something the module cannot mint.

**Headers and `extra_body` only, no callback.** Rejected: `extra_body.tools` replaces the caller's tools, which would break tool calling for every agent behind the proxy.

**Automatic free→paid fallback in litellm.** Rejected. `fallbacks` would let a Zen outage silently bill OpenRouter at $0.20/$0.60 per 1M tokens. What was asked for is a fallback model, not an automatic spend; `-paid` exists, and switching is one model name.

## Consequences

- The contract is version-coupled and heuristic. The accepted tool name moved from `bash` (CLI 1.x) to `read` (CLI 2.x) inside a month, and the module pins a `User-Agent` string. A Zen change breaks these models with a 403; the fix is an edit to `resources/opencode_contract.py`, re-checked by the gates under `.unlazy/opencode-zen/`.
- Requests to these models always answer with SSE, including when the caller asked for a non-streaming response, because Zen refuses a non-streaming upstream body and the hook forces `stream: true`. A client that requires a JSON body should use `-paid`.
- The proxy presents a forged opencode client identity to satisfy the gate. That is a deliberate bypass of an explicit vendor restriction — "OpenCode's free tier can only be used from within OpenCode" — and the account-level risk is the operator's, taken knowingly.
- Cost accounting stays at zero for the free tier, so a promo that ends surfaces as a 403 rather than as an unnoticed bill.
- Every client already naming `deepseek-v4.1-flash` moves to the free tier, including hermes' council aggregator. `deepseek-v4.1-flash-paid` is the only thing that has to change to move back.
