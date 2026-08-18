# LLMKube

Kubernetes operator ([defilantech/LLMKube](https://github.com/defilantech/LLMKube)) for
self-hosted llama.cpp inference, running in the `llm` namespace. Replaces the
hand-rolled app-template HelmReleases for GPU model serving.

A model is two CRs — a **`Model`** (where the weights come from + hardware
target) and an **`InferenceService`** (the serving pod: llama.cpp args, GPU,
probes, endpoint). The CRDs are cluster-wide, so each model's two CRs live **in
the folder of the app that consumes it**, not under `llmkube/`:

```
llmkube/                    # the operator + shared cluster infra only
  ocirepository.yaml  helmrelease.yaml  kustomization.yaml   # the operator
  servicemonitor.yaml       # one SM scrapes every InferenceService (job = service name)
  modelpool.yaml            # ai3090-slot — spans two apps, so it lives here
  modelrouter.yaml          # ai3090-router — activates a pool member on request

memini/                     # Intel iGPU helpers, reconciled by the `memini` KS
  memini-embed.yaml  memini-rerank.yaml  memini-summary.yaml

litellm/app/                # chat/vision models, reconciled by the `litellm` KS
  llama-qwen.yaml           # Qwen3.8-27B on RTX 3090 (vision via mmproj)

comfyui/app/                # image/video generation, reconciled by the `comfyui` KS
  model.yaml  inferenceservice.yaml   # runtime: generic, not llama.cpp
```

Each consuming app's own Flux Kustomization reconciles its models (`memini`,
`litellm` in `apps/ai/`); there is no dedicated `llmkube-models`
Kustomization. The CRDs come from the `llmkube` operator, so those apps assume
it's already reconciled (no explicit `dependsOn`).

## The ai3090 GPU slot (`ModelPool`)

`llama-qwen` and `comfyui` cannot co-reside in 24 GB, so `ModelPool/ai3090-slot`
makes them share one exclusive slot: at most one member is Ready, and the
incumbent is drained and unloaded (VRAM freed) before the next member loads.
Exclusivity comes from the device plugin — **every member must request
`resources.gpu: 1`**, or the pool cannot gate it.

Swapping is `sticky`: whoever holds the slot keeps it until the other member is
asked for. A busy incumbent is never cut off, and a swap that cannot establish
idleness stays deferred rather than forcing.

**Members must not declare `spec.replicas`.** The pool patches that field to
claim and release the slot, so a value in git makes Flux revert the pool on
every reconcile.

### Flipping the slot

The pool only _enforces_ the invariant; it never decides who should own the
slot. That decision comes from `ModelRouter/ai3090-router`, whose activator
scales a member up when a request names it. So the switch is a chat message:

| Want      | Do                                                                                                    |
| --------- | ----------------------------------------------------------------------------------------------------- |
| ComfyUI   | send anything to model `comfyui` (open-webui picker, hermes, or a POST to `litellm.${SECRET_DOMAIN}`) |
| Qwen back | nothing — the next `qwen-local` request drains ComfyUI and reloads it                                 |

`defaultRouteStrategy: BackendNameMatch` is what makes naming the model route
to that backend. ComfyUI's web UI can never trigger this itself: the activator
only fires on an OpenAI-shaped request, which a browser page load is not. The
`comfyui` LiteLLMModel exists purely to give that request somewhere to come
from, and `idle-probe.py` answers it with the UI's URL.

The caller must outlive the swap. A client that gives up first makes the
activator `Deactivate` the target, undoing the wake — hence `swapBudget: 1800s`
on the pool and `timeout: 1800` on the LiteLLMModel. First boot provisions
ComfyUI's weights and can exceed even that; do that one from a long-lived
client, after which the workspace PVC makes every later wake the fast path.

Draining needs an idle signal. llama.cpp gives one for free (`/slots`); the
`generic` runtime has none, so ComfyUI ships `idle-probe.py` (a preflight.d
script, since an InferenceService cannot run sidecars) answering the path in its
`inference.llmkube.dev/idle-endpoint` annotation. It reports busy on any error,
so a swap is never granted over a render the probe could not see.

> The router pins its proxy to one replica whenever a backend is a pool member:
> swaps serialize through an in-process lock, so a second replica would race it
> and thrash the slot.

## How weights are sourced

The `Model.spec.source` scheme decides what the operator does. Three modes:

| `source`                    | What happens                                                                                                                   | Persistence                   |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ----------------------------- |
| `pvc://<claim>/<path>.gguf` | Mounts the claim **read-only**. No download.                                                                                   | You staged it                 |
| `https://…/<file>.gguf`     | Init container `curl`s it into the **shared cache PVC** (`llmkube-model-cache`, CephFS RWX) on first start; skipped thereafter | Persistent, survives restarts |
| `<org>/<repo>` (bare HF id) | **vLLM runtime only** — not used by the llama.cpp runtime                                                                      | —                             |

> ⚠️ The cache (`modelCache` in `helmrelease.yaml`) **must stay enabled** for
> `https://` sources. With it disabled, downloads fall back to an ephemeral
> `emptyDir` and re-pull the full model on every pod restart.

## Adding a new model

Drop the `Model` + `InferenceService` file into the **consuming app's** folder
and add it to that app's `kustomization.yaml` — `memini/` for the Intel iGPU
helpers, `litellm/app/` for the chat/vision models. No new folder,
no Flux Kustomization — the operator and the app's existing Kustomization pick it up.

GPU access depends on the target:

- **Intel iGPU** — no claim, affinity used in the spec.
- **NVIDIA** — no claim; request `gpu: { count: 1 }` on the hardware block.

### Option A — let the operator download it (preferred for new models)

Point `source` at the **direct GGUF resolve URL** (not the repo id — the
llama.cpp init container `curl`s a single file):

```yaml
apiVersion: inference.llmkube.dev/v1alpha1
kind: Model
metadata:
    name: my-model
spec:
    source: https://huggingface.co/unsloth/<Repo>-GGUF/resolve/main/<File>.gguf
    format: gguf
    quantization: Q4_K_XL
    hardware:
        accelerator: gpu
        gpu: { enabled: true, vendor: nvidia, count: 1, layers: 99 }
```

On first reconcile the init container downloads into the shared CephFS cache;
later restarts reuse it. To re-pull after an upstream change, set
`spec.refreshPolicy: OnChange` (ETag revalidation each reconcile) — otherwise a
cached file is kept forever. Changing the `source` URL forces a fresh download
(the cache key is derived from the URL).

**Caveats**

- **No HF token** in this path — works for public GGUFs (unsloth, mradermacher).
  Gated/private repos must be pre-staged (Option B).
- **Single file only.** Multimodal models needing a separate `mmproj-*.gguf`
  can't be expressed as one `source` — pre-stage them (Option B).

### Option B — pre-stage on Ceph, then reference it

Use this for gated models, multi-file/vision models, or weights you already
have on `llmkube-models`. Download out of band, then:

```yaml
spec:
    source: pvc://llmkube-models/<dir>/<File>.gguf
```

A one-off download Job (same pattern as the old `model-download` initContainer):

```yaml
apiVersion: batch/v1
kind: Job
metadata:
    name: stage-my-model
spec:
    template:
        spec:
            restartPolicy: OnFailure
            containers:
                - name: hf
                  image: python:3.14-slim
                  command: ["/bin/sh", "-ec"]
                  args:
                      - |
                          pip install --no-cache-dir "huggingface_hub[hf_xet]"
                          hf download <org>/<repo> <File>.gguf --local-dir /models/<dir>
                  envFrom: [{ secretRef: { name: huggingface } }] # for gated repos
                  volumeMounts: [{ name: models, mountPath: /models }]
            volumes:
                - name: models
                  persistentVolumeClaim: { claimName: llmkube-models }
```

For Ceph PVC sources, remember `--no-mmap` (cold-fault rule) in the
`InferenceService.spec.extraArgs`.

## Continuity notes

- Name each `InferenceService` after its **consumer** (e.g. `memini-embed` for
  memini, etc). The `service` label on `llamacpp:*` metrics is the pod's
  `inference.llmkube.dev/service`, relabeled on by the PodMonitor, so renaming
  a service means updating any `service=~`/ `service!~` filters in the dashboards.
  Litellm routes follow `api_base` in the configmap, not the InferenceService name.
- Metrics come from the operator's PodMonitor
  (`prometheus.inferencePodMonitor.enabled: true`), which relabels
  `inference.llmkube.dev/{service,model,runtime}` onto every series. There's no
  hand-rolled ServiceMonitor anymore (retired with the idle-watcher). Pod and
  Service monitors both attach per-pod `pod`/`instance` labels, so the dashboards
  aggregate `by (service)` to keep a pod restart from fanning out into a new line
  per pod.
