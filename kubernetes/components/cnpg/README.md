## CloudNative PG

### Populate Secrets for new App

```
export APP=mealie
PASSWORD=$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9' | head -c 20 )
akeyless update-secret-val \
  --name cnpg-users \
  --custom-field "${APP}_postgres_username=${APP}" \
  --custom-field "${APP}_postgres_password=${PASSWORD}"
```

`${CNPG_NAME:=pgsql-cluster}` comes from each app's ks.yaml postBuild > substitute schema