## CloudNative PG

This component adds three things to an app: `${APP}-initdb-secret` (consumed by the `postgres-init` init container), `${APP}-pguser-secret` (host/user/password/uri/dsn), and a `${APP}-pg-backups` CronJob. All of it reads the role password from aKeyless `/database/cnpg-users`, field `${APP}_postgres_password`.

`${CNPG_NAME:=pgcluster-default}` comes from each app's `ks.yaml` `postBuild.substitute`.

### Getting the password into aKeyless

Two ways. Both end with the same field in the same place — this component never changes.

**Seeded (preferred for new apps).** ESO generates the password and pushes it. Nothing to run by hand. Two objects in the app's `app/`, both named `${APP}-pgpass` — see `apps/media/airwave/app/`:

```yaml
# externalsecret.yaml — a second document alongside the app's own secret
metadata:
    name: &name "${APP}-pgpass"
spec:
    refreshInterval: "0" # the generator is stateless — this is the ONLY thing pinning the value
    target: { name: *name }
    dataFrom:
        - sourceRef:
              generatorRef:
                  apiVersion: generators.external-secrets.io/v1alpha1
                  kind: Password
                  name: password32 # declared in components/secrets, exists in every namespace
```

```yaml
# pushsecret.yaml
spec:
    updatePolicy: IfNotExists
    selector: { secret: { name: "${APP}-pgpass" } }
    data:
        - match:
              secretKey: password
              remoteRef:
                  remoteKey: /database/cnpg-users
                  property: ${APP}_postgres_password
```

`updatePolicy: IfNotExists` is load-bearing, and it is checked **per property**, not per key — so it writes `${APP}_postgres_password` even though `/database/cnpg-users` already exists, and after that first write aKeyless is authoritative. A regenerated local password can never overwrite the stored one. The push also merges: only its own property is touched.

⚠️ On a first deploy this component's two ExternalSecrets reconcile before the push lands and report `SecretSyncedError` for a few seconds. That is the expected gap, not a fault — ESO templates with `missingkey=error`, so they write nothing rather than an empty password, then retry and succeed.

**Manual.** Still correct, and what every pre-existing app uses:

```
export APP=mealie
PASSWORD=$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9' | head -c 20 )
akeyless update-secret-val \
  --name cnpg-users \
  --custom-field "${APP}_postgres_username=${APP}" \
  --custom-field "${APP}_postgres_password=${PASSWORD}"
```
