# Getting Started

So you need to work on the cluster—maybe something's broken, maybe you want to add a new service, or maybe you're just curious how it all works. This guide will get you oriented.

## Prerequisites

You'll need access to the cluster and a few tools installed. Don't worry, the repository includes tool management through `mise`.

### What You Need

1. **Access to the repository**: Clone it from GitHub
2. **Kubeconfig file**: Fetch from existing cluster (see below) or generated during bootstrap
3. **Talosconfig file**: Fetch from existing cluster (see below) or generated during bootstrap
4. **Age key**: Located at `age.key` for decrypting secrets
5. **Tools**: Installed automatically via `mise` (see below)

??? info "Getting kubeconfig and talosconfig"
    These files contain cluster credentials and are **not** committed to Git. Both are stored in the repository root directory.

    **Scenario 1: Cloning from Git (existing cluster)**

    If the cluster is already running, fetch the config files:

    ```bash
    # Fetch talosconfig from existing cluster
    # Replace with your first control plane node IP
    talosctl config new talosconfig --endpoints 192.168.5.201 --nodes 192.168.5.201

    # Fetch kubeconfig from existing cluster
    talosctl kubeconfig -n 192.168.5.201 -f --force-context-name main

    # Verify both work
    export KUBECONFIG=$(pwd)/kubeconfig
    export TALOSCONFIG=$(pwd)/talosconfig
    kubectl get nodes
    talosctl health
    ```

    **Scenario 2: Bootstrapping from scratch**

    When bootstrapping a new cluster, both files are generated automatically:

    1. **Talosconfig**: Created in the repository root when you run `just bootstrap talos` (uses `--insecure` flag for initial config application)
    2. **Kubeconfig**: Generated during `just bootstrap kubeconfig` stage

    The [`.mise.toml`](https://github.com/tscibilia/home-ops/blob/main/.mise.toml) file automatically sets `KUBECONFIG` and `TALOSCONFIG` environment variables to point to these files in the repository root.

### Tool Installation

The repository uses [mise](https://mise.jdx.dev/) to manage tool versions. All required tools are defined in [`.mise.toml`](https://github.com/tscibilia/home-ops/blob/main/.mise.toml):

```bash
# Install mise (if not already installed)
curl https://mise.run | sh

# Install all tools defined in .mise.toml
mise install

# Tools installed include:
# - kubectl (Kubernetes CLI)
# - flux (Flux CD CLI)
# - helm (Helm package manager)
# - just (task runner)
# - talosctl (Talos OS CLI)
# - and many more...
```

??? tip "What is mise?"
    `mise` (formerly `rtx`) is a polyglot tool version manager. Instead of installing `kubectl`, `helm`, `flux`, etc. globally and managing versions yourself, mise reads `.mise.toml` and installs the exact versions the project expects. This ensures everyone working on the cluster uses the same tool versions.

    Think of it like `nvm` for Node.js, but for all CLI tools.

## Understanding the Repository Layout

Here's how the repository is organized:

```
home-ops/
├── bootstrap/          # Initial cluster setup (Helmfile)
├── kubernetes/         # All Kubernetes manifests
│   ├── apps/          # Applications organized by namespace
│   ├── components/    # Reusable Kustomize components
│   └── flux/          # Flux CD bootstrap config
├── talos/             # Talos OS configuration
├── .justfile          # Task runner commands
└── README.md          # Quick reference
```

??? question "What's the difference between `kubernetes/apps` and `bootstrap`?"
    - **`bootstrap/`**: Runs once during initial cluster setup using Helmfile. Deploys core infrastructure in the correct order (Cilium → CoreDNS → cert-manager → etc.)
    - **`kubernetes/apps/`**: Continuous GitOps managed by Flux. These apps are monitored and automatically synced from Git.

    After bootstrapping, you'll rarely touch `bootstrap/` unless you're rebuilding the entire cluster.

## The Task Runner: `just`

Instead of memorizing long `kubectl` and `flux` commands, everything is wrapped in `just` commands. Think of it like `make`, but better.

### Common Commands

```bash
# View all available commands
just --list

# Kubernetes operations
just kube sync-all-hr              # Sync all Helm releases
just kube ks-reconcile default authentik   # Force reconcile specific app
just kube view-secret default my-secret    # Decode and view secret

# Flux operations
just kube sync-git                 # Sync all Git repositories
just kube hr-restart              # Restart failed Helm releases

# Talos operations
just talos apply-node talos-m01   # Apply config to node
just talos reboot-node talos-m01  # Reboot a node
```

Full command reference: [Task Runner Reference](../operations/task-runner.md)

## How GitOps Works Here

The workflow is simple:

1. **Make changes locally**: Edit YAML files in `kubernetes/apps/`
2. **Test locally** (optional): `just kube apply-ks <namespace> <app>`
3. **Commit and push**: `git add`, `git commit`, `git push`
4. **Flux syncs automatically**: Within 1 hour, or force it: `just kube ks-reconcile <namespace> <app>`

### Example: Updating an App

Let's say you want to update Plex's configuration:

```bash
# 1. Edit the HelmRelease values
nano kubernetes/apps/media/plex/app/helmrelease.yaml

# 2. Test locally using flux-local (optional but recommended)
just kube apply-ks media plex

# 3. Commit and push
git add kubernetes/apps/media/plex/
git commit -m "feat(plex): update transcoding settings"
git push

# 4. Force Flux to sync immediately (or wait for automatic reconciliation)
just kube ks-reconcile media plex

# 5. Watch the rollout
kubectl rollout status deployment/plex -n media -w
```

??? info "What is flux-local?"
    `flux-local` is a tool that renders Flux Kustomizations locally without applying them to the cluster. When you run `just kube apply-ks`, it uses flux-local to validate your changes work before pushing to Git.

    This catches errors like:
    - Syntax errors in YAML
    - Missing Helm values
    - Broken Kustomize overlays

## Application Structure

Every application follows the same pattern. Let's look at `kubernetes/apps/default/authentik/` as an example:

```
authentik/
├── ks.yaml                 # Flux Kustomization
├── app/
│   ├── kustomization.yaml  # Kustomize resources list
│   ├── helmrelease.yaml    # Helm chart + values
│   ├── ocirepository.yaml  # Where to fetch the chart
│   └── externalsecret.yaml # Secrets from aKeyless
└── namespace.yaml          # Namespace definition
```

### What Each File Does

=== "ks.yaml"
    The Flux Kustomization ties everything together:

    - Points to `./app` directory
    - Defines dependencies (`dependsOn`)
    - Sets variable substitutions (`postBuild.substitute`)
    - Includes reusable components

    ```yaml title="kubernetes/apps/default/authentik/ks.yaml"
    spec:
      path: ./kubernetes/apps/default/authentik/app
      dependsOn:
        - name: cnpg-cluster  # Wait for database
          namespace: database
      postBuild:
        substitute:
          APP: authentik
          GATUS_SUBDOMAIN: auth
    ```

=== "helmrelease.yaml"
    The Helm chart configuration:

    - Chart name and version
    - Values (overrides chart defaults)
    - Update intervals

    ```yaml title="kubernetes/apps/default/authentik/app/helmrelease.yaml"
    spec:
      chart:
        spec:
          chart: authentik
          version: 2024.10.1
          sourceRef:
            kind: OCIRepository
            name: authentik
      values:
        replicas: 2
        envFrom:
          - secretRef:
              name: authentik-secret
    ```

=== "ocirepository.yaml"
    Where Flux fetches the Helm chart:

    ```yaml title="kubernetes/apps/default/authentik/app/ocirepository.yaml"
    spec:
      url: oci://ghcr.io/goauthentik/charts
      interval: 6h
    ```

=== "externalsecret.yaml"
    Syncs secrets from aKeyless:

    ```yaml title="kubernetes/apps/default/authentik/app/externalsecret.yaml"
    spec:
      target:
        name: authentik-secret
      dataFrom:
        - extract:
            key: authentik
    ```

??? tip "Where do I find the Helm chart values?"
    Each chart has different values you can override. To see available options:

    1. Check the chart's documentation (usually GitHub repository)
    2. Use `helm show values <chart>` after adding the repo
    3. Look at the chart's `values.yaml` in the OCI repository

    For Authentik specifically: [Authentik Helm Chart Docs](https://goauthentik.io/docs/installation/kubernetes)

## Next Steps

Now that you understand the basics:

- [**Infrastructure**](../infrastructure/overview.md): Learn how the cluster is built from scratch
- [**Kubernetes**](../kubernetes/overview.md): Deep dive into app management and Flux patterns
- [**Operations**](../operations/overview.md): Day-to-day maintenance and troubleshooting
- [**Networking**](../kubernetes/networking.md): How services are exposed and accessed

??? question "Something's Broken, Help!"
    Jump straight to the [Troubleshooting Guide](../operations/troubleshooting.md) for common issues and solutions.
