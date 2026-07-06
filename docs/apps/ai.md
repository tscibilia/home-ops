# AI

Namespace: `ai`

| App         | Storage  | Notes                                                   |
| ----------- | -------- | ------------------------------------------------------- |
| comfyui     | ceph-ssd | Image generation, external access                       |
| honcho      | —        | AI memory service, pgvector-cluster + Dragonfly DB 6    |
| litellm     | —        | LLM API proxy, internal only, Redis cache via Dragonfly |
| llama-cpp   | ceph-ssd | NVIDIA GPU (ai3090), CUDA inference server              |
| mcp-servers | —        | MCPServer CRDs managed by toolhive operator             |
| open-webui  | ceph-ssd | LLM chat UI, external access, kopiur backup             |
| toolhive    | —        | MCP operator, depends on Dragonfly                      |

## Config Notes

### honcho

AI memory service by [plastic-labs](https://github.com/plastic-labs/honcho). Backed by pgvector-cluster (Postgres with vector extension) and Dragonfly DB 6 for caching. Runs two controllers: `api` (FastAPI, port 8000) and `deriver` (background embedding worker). Schema migrations run via `alembic upgrade head` init container on every deploy. The `vector` extension must exist in the honcho database before migrations can run — was created manually via `kubectl exec` on pgvector-cluster; would need to be recreated if the database is wiped.

### llama-cpp

Scheduled on ai3090 (needs `nvidia.com/gpu` toleration). Runs llama.cpp server with CUDA GPU acceleration.

### toolhive

Operator-based MCP (Model Context Protocol) lifecycle manager. Depends on dragonfly-cluster for state. Manages MCPServer CRDs; deployed as three Kustomizations (crds → operator → config).

### mcp-servers

MCPServer CRDs (context7, hass, flux, kubectl) managed by toolhive. Each is a separate MCP server accessible to AI clients. Uses groupRef `mcp-ext`.
