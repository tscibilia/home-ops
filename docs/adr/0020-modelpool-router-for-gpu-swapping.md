# One GPU slot, swapped on request, arbitrated by LLMKube

**Status:** accepted
**Date:** 2026-08-18

`ai3090` has a single RTX 3090. Qwen3.8-27B and ComfyUI's Flux weights cannot co-reside in 24 GB, and the node cannot even co-schedule them — the two pods request 20 Gi and 12 Gi of host memory against a node that has less. Whichever workload is wanted must therefore evict the other. `ModelPool/ai3090-slot` owns that eviction and `ModelRouter/ai3090-router` decides when it happens, so switching is a chat message rather than an edit to git.

ComfyUI is expressed as an LLMKube `InferenceService` on `runtime: generic` — an image, a command, volumes and probes, with no llama.cpp semantics attached. That is the price of entry: the pool arbitrates `InferenceService` members and nothing else.

## Considered options

**Leave both running and rely on VRAM sleep.** llama.cpp frees device memory after `--sleep-idle-seconds`, and ComfyUI can be told to unload between jobs, so a two-sided idle-unload almost works. Rejected once the node's memory request was accounted for: the pods cannot both be scheduled, sleep or no sleep. It would also have been a race with no arbiter — two processes each assuming the card is free.

**PriorityClass preemption.** Give ComfyUI the higher class and let the scheduler evict Qwen. Rejected because preemption is indifferent to work in flight; it kills a generation mid-token. The whole value of the pool is that a busy incumbent is never cut off.

**llama-swap.** The pre-LLMKube candidate. It swaps processes on one host, not pods in a cluster, and llama.cpp has since absorbed both sleep mode and router mode. Adopting it now would mean running two orchestrators over the same GPU.

**ModelPool without a ModelRouter.** Rejected on discovery, not on merit: the pool only _enforces_ the invariant. `Activate` lives in the router-proxy, so with no router nothing ever wakes a member and every switch is a manual `replicas` edit. This is the single least obvious fact about the design.

**A webhook or agent that patches `replicas`.** The obvious alternative to a router, and the reason it was not taken is that nothing in the cluster can already do it: the kubectl MCP server runs `--read-only`, and the flux MCP's write role covers Flux API groups only. It would have meant granting a chat session write access to `InferenceService` — a wide grant to replace a mechanism LLMKube already ships.

## Consequences

- **Naming a model is the switch.** `defaultRouteStrategy: BackendNameMatch` sends a request whose `model` names a backend straight to it, and the activator wakes it if stopped. Sending anything to the `comfyui` LiteLLM model swaps ComfyUI in; any ordinary `qwen-local` request swaps it back. ComfyUI's own web UI can never trigger this — a browser page load is not an OpenAI request.
- **The `llama-qwen` backend carries `displayName: Qwen3.8-27B`.** Resolution happens on the published id, so litellm still sends the model name llama.cpp knows from its `--alias` and only `apiBase` moved. Renaming either half silently breaks routing.
- **Members must not declare `spec.replicas`.** The pool patches that field to claim and release the slot; a value in git makes Flux revert it on every reconcile. Ownership of a spec field moves from git to a controller, so flipping the slot by hand is a live `kubectl patch`, not a commit.
- **A member that cannot start wedges the slot.** There is no force-unload timeout by design, and the documented escape — an admin editing `replicas` — does not work, because the reconciler re-asserts it mid-swap. The real escape is removing the member from `spec.members`. Proven the day this shipped: a crash-looping ComfyUI held the GPU and kept `llama-qwen` at zero for roughly twenty minutes.
- **`swapBudget` is the blast radius of a failed wake.** It bounds how long a held request waits, and the wait is also the outage. It is set to 1800s so a cold ComfyUI can finish; that number is a deliberate trade against the wedge above and should fall once first-boot cost is known.
- **A caller that gives up undoes the wake.** When the last waiter for a member disconnects or times out, the activator calls `Deactivate` and scales it back to zero. Client timeouts must therefore outlast a cold start; litellm's `router_settings.timeout` is the real ceiling, not the per-model `timeout`.
- **The router-proxy is pinned to one replica** whenever a backend is a pool member. Swaps serialise through an in-process lock, so a second replica would race it.
- **Drain needs an idle signal per runtime.** llama.cpp answers `/slots`; `generic` has none, so ComfyUI ships `idle-probe.py` behind the `inference.llmkube.dev/idle-endpoint` annotation, reporting busy on any error so a swap is never granted over a render the probe could not see. The probe must serve on `spec.containerPort` — LLMKube probes `http://<podIP>:<containerPort>` and cannot reach a second port — so the probe owns 9000 and the web UI keeps 8188 behind a hand-written Service and HTTPRoute.
- **An `InferenceService` cannot run sidecars or init containers.** The probe is started by overriding the image's `command`/`args` and backgrounding it ahead of the original entrypoint. Any image swap has to re-establish that, along with `PIP_TARGET`/`PYTHONPATH` — ComfyUI-Manager installs node dependencies into the image's site-packages otherwise, and every swap discards them.
- **The GPU request is load-bearing.** Exclusivity comes from the device plugin holding the incoming pod `Pending` until the incumbent's pod is gone. A member without `resources.gpu: 1` is not gated by anything, which is what the pre-pool ComfyUI deliberately did.
