## Immich
---

Liked the immich-config file concept from ant385525 https://github.com/ant385525/home-ops/tree/main/kubernetes/apps/home/immich
- But I wanted to easily pass secrets and variables from the main immich app to the config file, so I followed @ishioni for that part
- The rest of my config followed ant385525 more closely
- Did not setup metrics-api service ports

Inspired by the configs from ishioni https://github.com/ishioni/homelab-ops/tree/master/kubernetes/apps/selfhosted/immich
- Used the immich-config file concept that created a template configMap then used a transformer configuration to create a secret using variables from my external secrets

## TODOs
- Rename server container `app` to `srv` it might look more consistent with `immich-ml` to also have `immich-srv` and update the configs to match
- Consider a local `/cache` pvc instead of using an emptyDir
- Add a loadbalancerIP for local file transfer over wifi, not sure if this improves speed