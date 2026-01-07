# Secrets Management

The cluster uses **aKeyless** as the central secrets management platform. Secrets are accessed through three different authentication methods depending on the use case.

## aKeyless Authentication Methods

### 1. Web GUI (Email Authentication)

**Use case**: Manual secret management, administrative tasks

**Access**: Log in to [aKeyless Console](https://console.akeyless.io) with email and password

**What you can do:**
- Create/update/delete secrets
- Create database users for CNPG (see [CNPG section](#cnpg-database-secrets))
- View secret values
- Manage access policies

??? example "Creating a Secret via Web GUI"
    1. Log in to aKeyless Console
    2. Navigate to **Items** → **Secrets**
    3. Click **+ New** → **Static Secret**
    4. Enter path (e.g., `authentik`) and secret value (JSON or plain text)
    5. Save

### 2. Talos ESO (API Authentication)

**Use case**: Kubernetes apps syncing secrets automatically

**Method**: External Secrets Operator (ESO) authenticates to aKeyless API

**How it works:**

ESO runs in the cluster and automatically syncs secrets from aKeyless to Kubernetes Secrets. The [`ClusterSecretStore`](https://github.com/tscibilia/home-ops/blob/main/kubernetes/apps/external-secrets/secret-stores/akeyless/clustersecretstore.yaml) configures API authentication:

```yaml title="kubernetes/apps/external-secrets/secret-stores/akeyless/clustersecretstore.yaml"
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: akeyless-secret-store
spec:
  provider:
    akeyless:
      akeylessGWApiURL: "https://api.akeyless.io"
      authSecretRef:
        secretRef:
          accessID:
            name: akeyless-secret
            key: accessId
            namespace: external-secrets
          accessType:
            name: akeyless-secret
            key: accessType
            namespace: external-secrets
          accessTypeParam:
            name: akeyless-secret
            key: accessTypeParam
            namespace: external-secrets
```

Apps create `ExternalSecret` CRDs that reference the ClusterSecretStore, and ESO handles fetching secrets from aKeyless API automatically.

**This method is completely hands-off**—once configured, ESO syncs secrets automatically without manual intervention.

### 3. Akeyless Agent (CLI Authentication)

**Use case**: Bootstrap process, Talos configuration, template rendering

**Method**: `akeyless` CLI configured with API key, used by [`akeyless-inject.sh`](https://github.com/tscibilia/home-ops/blob/main/bootstrap/scripts/akeyless-inject.sh)

**How it works:**

Talos configuration templates and bootstrap resources use `ak://` references:

```yaml title="Example from talos/machineconfig.yaml.j2"
machine:
  ca:
    crt: ak://talos/MACHINE_CA_CRT
    key: ak://talos/MACHINE_CA_KEY
  token: ak://talos/MACHINE_TOKEN
```

During rendering, [`akeyless-inject.sh`](https://github.com/tscibilia/home-ops/blob/main/bootstrap/scripts/akeyless-inject.sh) uses the `akeyless` CLI to replace `ak://` references with actual secret values fetched from aKeyless.

**Setup:**

```bash
# Configure CLI with API key
akeyless configure --access-type api_key \
  --access-id <your-access-id> \
  --access-key <your-access-key>

# Authenticate
akeyless auth

# Test retrieval
akeyless get-secret-value --name talos/MACHINE_TOKEN
```

??? info "`ak://` Reference Format"
    The script supports two formats:

    - **Plain text secret**: `ak://path/to/secret`
      - Example: `ak://talos/token`
      - Returns: The raw secret value

    - **JSON field extraction**: `ak://secret/FIELD_NAME`
      - Example: `ak://talos/MACHINE_TOKEN`
      - Returns: The value of `MACHINE_TOKEN` key from JSON

    Nested paths work: `ak://deeply/nested/path/to/secret/FIELD`

**Where CLI method is used:**
- Bootstrap resources: [`bootstrap/resources.yaml.j2`](https://github.com/tscibilia/home-ops/blob/main/bootstrap/resources.yaml.j2)
- Talos config rendering: `just talos render-config`
- Template rendering: `just template <file>`

---

## Kubernetes External Secrets Operator (ESO)

Once the cluster is running, Kubernetes apps use **External Secrets Operator** to sync secrets from aKeyless via the API.

### ClusterSecretStore

The [`ClusterSecretStore`](https://github.com/tscibilia/home-ops/blob/main/kubernetes/apps/external-secrets/secret-stores/akeyless/clustersecretstore.yaml) is configured during [bootstrap](../infrastructure/bootstrap.md#stage-6-apply-resources). It authenticates ESO to aKeyless using credentials stored in the `akeyless-secret` Secret.

### ExternalSecret CRDs

Apps define `ExternalSecret` CRDs to sync secrets from aKeyless:

```yaml title="Example: kubernetes/apps/default/authentik/app/externalsecret.yaml"
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: authentik
spec:
  secretStoreRef:
    name: akeyless-secret-store
    kind: ClusterSecretStore
  target:
    name: authentik-secret  # Creates this Kubernetes Secret
  dataFrom:
    - extract:
        key: authentik  # Fetches from aKeyless path
```

ESO automatically:

1. Fetches `authentik` secret from aKeyless API
2. Creates a Kubernetes Secret named `authentik-secret`
3. Syncs changes every 1 hour (configurable)

**Apps reference this secret:**

```yaml title="kubernetes/apps/default/authentik/app/helmrelease.yaml"
envFrom:
  - secretRef:
      name: authentik-secret
```

---

## Secret Workflows

### Adding a New Secret for an App

1. **Create secret in aKeyless** (via Web GUI or CLI):

    ```bash
    # Create JSON secret with multiple keys
    akeyless create-secret \
      --name myapp \
      --value '{"API_KEY":"xxx","DATABASE_URL":"yyy"}'
    ```

2. **Create ExternalSecret CRD**:

    ```yaml title="kubernetes/apps/default/myapp/app/externalsecret.yaml"
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: myapp
    spec:
      secretStoreRef:
        name: akeyless-secret-store
        kind: ClusterSecretStore
      target:
        name: myapp-secret
      dataFrom:
        - extract:
            key: myapp
    ```

3. **Reference in HelmRelease**:

    ```yaml title="kubernetes/apps/default/myapp/app/helmrelease.yaml"
    envFrom:
      - secretRef:
          name: myapp-secret
    ```

4. **Deploy**:

    ```bash
    git add kubernetes/apps/default/myapp/
    git commit -m "feat(myapp): add secrets"
    git push

    # Force sync if needed
    just kube sync-es default myapp
    ```

### Updating an Existing Secret

1. **Update in aKeyless** (Web GUI or CLI):

    ```bash
    akeyless update-secret-value \
      --name authentik \
      --value '{"SECRET_KEY":"new-value"}'
    ```

2. **Force ESO to resync**:

    ```bash
    just kube sync-es default authentik
    ```

3. **Restart app to pick up new secret**:

    ```bash
    kubectl rollout restart deployment/authentik -n default
    ```

---

## CNPG Database Secrets

**IMPORTANT**: The CNPG component does **not** automatically generate database user secrets. You must create them manually in aKeyless (via Web GUI or CLI).

### Creating Database User Secrets

When using the [`cnpg` component](https://github.com/tscibilia/home-ops/tree/main/kubernetes/components/cnpg), you need to manually create secrets for database users in aKeyless.

**Steps:**

1. **Create secret in aKeyless** (Web GUI or CLI):

    ```bash
    # Create JSON secret with database credentials
    akeyless create-secret \
      --name <app-name>-pguser \
      --value '{"username":"<app-name>","password":"<random-password>","dbname":"<app-name>"}'
    ```

    Example for Authentik:

    ```bash
    akeyless create-secret \
      --name authentik-pguser \
      --value '{"username":"authentik","password":"$(openssl rand -base64 32)","dbname":"authentik"}'
    ```

2. **Include CNPG component in app's `ks.yaml`**:

    ```yaml title="kubernetes/apps/default/authentik/ks.yaml"
    spec:
      components:
        - ../../../../components/cnpg
      postBuild:
        substitute:
          APP: authentik
          CNPG_NAME: pgsql-cluster
    ```

3. **CNPG component creates ExternalSecret**:

    The component automatically creates an `ExternalSecret` that syncs `${APP}-pguser` from aKeyless into a Kubernetes Secret named `${APP}-pguser-secret`.

4. **CNPG component CronJob creates database user**:

    The component includes a CronJob ([`kubernetes/components/cnpg/cronjob.yaml`](https://github.com/tscibilia/home-ops/blob/main/kubernetes/components/cnpg/cronjob.yaml)) that runs daily to ensure the database user exists in PostgreSQL using the credentials from aKeyless.

5. **App references the secret**:

    ```yaml title="kubernetes/apps/default/authentik/app/helmrelease.yaml"
    env:
      - name: AUTHENTIK_POSTGRESQL__USER
        valueFrom:
          secretKeyRef:
            name: authentik-pguser-secret
            key: username
      - name: AUTHENTIK_POSTGRESQL__PASSWORD
        valueFrom:
          secretKeyRef:
            name: authentik-pguser-secret
            key: password
    ```

??? warning "Secret Must Exist Before Deployment"
    If the `<app-name>-pguser` secret doesn't exist in aKeyless, the ExternalSecret will fail to sync and the app won't start:

    ```
    ERROR: secret "authentik-pguser" not found in aKeyless
    ```

    **Always create the secret in aKeyless first** (step 1 above) before deploying the app.

### CNPG Component Breakdown

Located at [`kubernetes/components/cnpg/`](https://github.com/tscibilia/home-ops/tree/main/kubernetes/components/cnpg):

1. **ExternalSecret** ([`externalsecret.yaml`](https://github.com/tscibilia/home-ops/blob/main/kubernetes/components/cnpg/externalsecret.yaml)): Syncs `${APP}-pguser` from aKeyless to Kubernetes Secret
2. **CronJob** ([`cronjob.yaml`](https://github.com/tscibilia/home-ops/blob/main/kubernetes/components/cnpg/cronjob.yaml)): Runs daily to ensure database user exists in PostgreSQL

Apps using PostgreSQL:

- Authentik
- Gatus
- Immich
- And others in the `default` namespace

---

## Bootstrap Secrets

During bootstrap, secrets are injected via the CLI method. See [`bootstrap/resources.yaml.j2`](https://github.com/tscibilia/home-ops/blob/main/bootstrap/resources.yaml.j2) for examples of `ak://` references used to create bootstrap-time Secrets.

These include:

- `akeyless-secret`: ESO authentication credentials
- `cloudflared-secret`: Cloudflare tunnel credentials
- `cluster-secrets`: Cluster-wide variables (referenced by apps via `postBuild.substituteFrom`)

---

## Troubleshooting Secrets

### ExternalSecret Not Syncing

**Symptoms**: `SecretSyncedError` status on ExternalSecret

**Diagnosis**:

```bash
kubectl describe externalsecret <name> -n <namespace>
```

**Common causes**:

1. **Secret doesn't exist in aKeyless**:

    ```
    ERROR: secret not found: <secret-name>
    ```

    **Fix**: Create the secret in aKeyless Web GUI or CLI

2. **ClusterSecretStore not ready**:

    ```bash
    kubectl get clustersecretstore
    ```

    **Fix**: Check ESO operator logs:

    ```bash
    kubectl logs -n external-secrets deployment/external-secrets
    ```

3. **Authentication failed**:

    ```
    ERROR: authentication failed
    ```

    **Fix**: Verify `akeyless-secret` contains correct credentials:

    ```bash
    kubectl get secret akeyless-secret -n external-secrets -o yaml
    ```

### Force Resync ExternalSecret

```bash
# Single secret
just kube sync-es <namespace> <secret-name>

# All secrets
just kube sync-all-es
```

### Viewing Decoded Secrets

```bash
# Decode and view secret
just kube view-secret <namespace> <secret-name>

# Or manually
kubectl get secret <name> -n <namespace> -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key): \(.value | @base64d)"'
```

### akeyless-inject.sh Not Resolving References

**Symptoms**: `ak://` references not replaced during bootstrap or template rendering

**Cause**: aKeyless CLI not authenticated

**Fix**:

```bash
# Re-authenticate
akeyless auth

# Test secret retrieval
akeyless get-secret-value --name talos/MACHINE_TOKEN

# Re-run the failed stage
just bootstrap resources  # or whichever stage failed
```

---

## Best Practices

1. **Use JSON secrets**: Store multiple related values in one secret (e.g., database credentials)
2. **Name consistently**: Use `<app-name>` for app secrets, `<app-name>-pguser` for database credentials
3. **Rotate regularly**: Update secrets in aKeyless and force resync
4. **Limit access**: Use aKeyless access policies to restrict who can view/modify secrets
5. **Never commit secrets**: All secrets live in aKeyless, never in Git (even encrypted)

---

## Secret Reference Summary

| Authentication Method | Use Case | How It Works |
|----------------------|----------|--------------|
| **Web GUI (Email)** | Manual management, creating secrets | Log in to aKeyless Console with email/password |
| **Talos ESO (API)** | Kubernetes apps syncing secrets | ClusterSecretStore authenticates ESO to aKeyless API; ExternalSecret CRDs fetch secrets automatically |
| **Akeyless Agent (CLI)** | Bootstrap, Talos configs, templates | `akeyless-inject.sh` uses CLI to resolve `ak://` references in Jinja2 templates |

---

## Next Steps

- [Bootstrap Guide](../infrastructure/bootstrap.md): How secrets are injected during cluster setup
- [Operations Guide](../operations/overview.md): Managing secrets in production
- [Troubleshooting](../operations/troubleshooting.md): Fixing ExternalSecret sync failures
