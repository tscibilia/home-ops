## Headlamp

### Getting headlamp to work with Talos and Authentik
Headlamp was easy to deploy but the logs sucked as of v0.32.0 and I couldn't login via OIDC (well I could but I was being recognized as the user `anonymous`). After much troubleshooting and begrudgingly ChatGPTing, I figured out that it would be easiest to provide headlamp with my `groups` scope from Authentik [here](https://github.com/tscibilia/home-ops/blob/3e53bfd96de3f7b4500df84ed18da551ee0f235a/kubernetes/apps/flux-system/headlamp/app/externalsecret.yaml#L19). I did consider adding a role of `cluster-admin` to the Authentik admin group, but it turns out it wasn't necessary.
- So I added it to the `headlamp-secret` which I [previously established](https://github.com/tscibilia/home-ops/blob/3e53bfd96de3f7b4500df84ed18da551ee0f235a/kubernetes/apps/flux-system/headlamp/app/helmrelease.yaml#L49-L54) as the oidc secret (instead of letting headlamp generate the secret on it's own).
- I then realized it still wasn't regonizing my group credentials and added the `kind: Groups` to the rbac `ClusterRoleBinding` [here](https://github.com/tscibilia/home-ops/blob/3e53bfd96de3f7b4500df84ed18da551ee0f235a/kubernetes/apps/flux-system/headlamp/app/rbac.yaml#L33-L35).
- This didn't improve the situtation and later found that Talos needed me to modify the clusterconfigs under `cluster.apiServer.extraArgs:` to include the headlamp OIDC credentials. ChatGPT suggested this but confirmed it was a possible solution by looking at [jfroy/flatops](https://github.com/jfroy/flatops) configs.

Needless to say the [Headlamp documentation](https://headlamp.dev/docs/latest/installation/in-cluster/oidc/) was unhelpful and [Authentik](https://version-2024-4.goauthentik.io/integrations/) didn't have a convenient tutorial, so I was stuck for a few days looking at headlamp's GitHub issues.

### Links
Some helpful reading that lead me to this point:
- https://github.com/siderolabs/talos/discussions/6880
- https://medium.com/elmo-software/kubernetes-authenticating-to-your-cluster-using-keycloak-eba81710f49b
- https://github.com/kubernetes-sigs/headlamp/issues/3441
- https://github.com/kubernetes-sigs/headlamp/discussions/2707
