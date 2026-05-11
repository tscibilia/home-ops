# AI

Namespace: `ai`

| App          | Storage  | Notes                                              |
| ------------ | -------- | -------------------------------------------------- |
| comfyui      | ceph-ssd | Image generation, external access                  |
| llama-cpp    | ceph-ssd | NVIDIA GPU (ai3090), CUDA inference server         |
| mcp-servers  | —        | MCPServer CRDs managed by toolhive operator        |
| open-webui   | ceph-ssd | LLM chat UI, external access, volsync backup       |
| toolhive     | —        | MCP operator, depends on Dragonfly                 |

## Config Notes

### llama-cpp

Scheduled on ai3090 (needs `nvidia.com/gpu` toleration). Runs llama.cpp server with CUDA GPU acceleration.

### toolhive

Operator-based MCP (Model Context Protocol) lifecycle manager. Depends on dragonfly-cluster for state. Manages MCPServer CRDs; deployed as three Kustomizations (crds → operator → config).

### mcp-servers

MCPServer CRDs (context7, hass, flux, kubectl) managed by toolhive. Each is a separate MCP server accessible to AI clients. Uses groupRef `mcp-ext`.
