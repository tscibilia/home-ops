## qBittorrent
---

Inspired by the configs from bjw-s https://github.com/bjw-s-labs/home-ops/tree/main/kubernetes/apps/downloads/qbittorrent
- Used CoreDNS as initContainer
- Used kube-system/generic-device-plugin to establish a tun/tap
- Used gluetun and squat.ai/tun to establish a VPN connection
- Used home-operations/qbittorrent
  - I'm having issues writing the config via env vars (I even tried a fresh install and it would start)
```bash
2025-05-18T20:49:55.457075414Z cp: cannot create regular file '/config/qBittorrent/qBittorrent.conf': Permission denied
2025-05-18T20:49:55.463464486Z mkdir: cannot create directory ‘/config/qBittorrent/logs’: Permission denied
2025-05-18T20:49:55.470185599Z ln: failed to create symbolic link '/config/qBittorrent/logs/qbittorrent.log': No such file or directory
```
- Used gluetun-qb-port-sync (the underlying script seems to fail for me)
  - The script fails because `nc` cant reach my own publis IPP from inside the container
  - GPT suggests to have it always exit successfully with something like
```bash
nc -z -w5 localhost "${gluetun_port}" || true
exit 0
```
- Used socks5 proxy to allow external connections (i.e. prowlarr), but this is failing due to the port-sync failure
- Used vmrule from @mchestr
- Not using xseed configs

### TODOs
- Install management tools, start with qbitmanage
  - https://github.com/heavybullets8/heavy-ops/blob/main/kubernetes/apps/media/qbittorrent/qbitmanage/helmrelease.yaml
  - Fall back on @buroa qbtools https://github.com/buroa/qbtools (note it requires sabnzb)
- Look for new wg-capable VPN that works with gluetun prior to PIA subscription ending
  - https://github.com/qdm12/gluetun-wiki/blob/main/setup/wireguard.md