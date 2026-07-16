# AI

Namespace: `ai`

| App         | Storage  | Notes                                                     |
| ----------- | -------- | --------------------------------------------------------- |
| comfyui     | ceph-ssd | Image generation, external access                         |
| memini      | —        | AI memory/context, pgvector-cluster, llmkube embed+rerank |
| litellm     | —        | LLM API proxy, internal only, Redis cache via Dragonfly   |
| llama-qwen  | —        | NVIDIA GPU (ai3090), llmkube InferenceService, CUDA       |
| llama-gemma | —        | NVIDIA GPU (ai3090), llmkube InferenceService, dormant    |
| mcp-servers | —        | MCPServer CRDs managed by toolhive operator               |
| open-webui  | ceph-ssd | LLM chat UI, external access, kopiur backup               |
| toolhive    | —        | MCP operator, depends on Dragonfly                        |

## Config Notes

### memini

AI memory/context service by [eleboucher](https://git.erwanleboucher.dev/eleboucher/memini). Backed by pgvector-cluster (vchord + vector). Embedding and rerank run as llmkube InferenceServices (`memini-embed`, `memini-rerank`) on the Intel iGPU node, routing through litellm. Stores agent session memories with semantic search. API keys managed per-agent (hermes, opencode).

### llama-qwen / llama-gemma

llmkube Model + InferenceService CRs replacing the old helm-based llama-cpp. Both use `hf://` source with `files:[]` + `mmproj:` for multimodal support. Models cache on node-local NVMe (perService, 20Gi). Only one holds the GPU at a time:

- **llama-qwen** (`priority: high`, `replicas: 1`) — primary model, Qwen3.6-27B IQ4_NL
- **llama-gemma** (`priority: normal`, `replicas: 0`) — dormant, scale up via `kubectl scale isvc` when needed

### toolhive

Operator-based MCP (Model Context Protocol) lifecycle manager. Depends on dragonfly-cluster for state. Manages MCPServer CRDs; deployed as three Kustomizations (crds → operator → config).

### mcp-servers

MCPServer CRDs (context7, hass, flux, kubectl) managed by toolhive. Each is a separate MCP server accessible to AI clients. Uses groupRef `mcp-ext`.
