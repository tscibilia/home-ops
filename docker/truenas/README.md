## Cron job doco-cd update

### cron-script.sh
```bash
cd /mnt/nas/data/users/sysadmin/.config/doco-cd && \

CHANGED=0 && \

NEW_HASH=$(curl -s https://raw.githubusercontent.com/tscibilia/home-ops/main/docker/truenas/.doco-cd/docker-compose.app.yaml | sha256sum | cut -d' ' -f1) && \
OLD_HASH=$(sha256sum docker-compose.yaml 2>/dev/null | cut -d' ' -f1) && \
[ "$NEW_HASH" != "$OLD_HASH" ] && \
curl -s https://raw.githubusercontent.com/tscibilia/home-ops/main/docker/truenas/.doco-cd/docker-compose.app.yaml -o docker-compose.yaml && \
CHANGED=1 || true && \

NEW_HASH=$(curl -s https://raw.githubusercontent.com/tscibilia/home-ops/main/docker/truenas/.doco-cd/Dockerfile | sha256sum | cut -d' ' -f1) && \
OLD_HASH=$(sha256sum Dockerfile 2>/dev/null | cut -d' ' -f1) && \
[ "$NEW_HASH" != "$OLD_HASH" ] && \
curl -s https://raw.githubusercontent.com/tscibilia/home-ops/main/docker/truenas/.doco-cd/Dockerfile -o Dockerfile && \
CHANGED=1 || true && \

[ "$CHANGED" -eq 1 ] && docker compose up -d --build --force-recreate
```

### cron job
```bash
0 6 * * * /mnt/nas/data/users/sysadmin/.config/doco-cd/cron-script.sh >> /var/log/doco-cd-update.log 2>&1
```
- User: root
- Shell: /bin/bash
