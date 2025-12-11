# Active Work & Known Issues

This document is intended to supplement and connect with GitHub issues and meant to provide AI agents with context regarding planned revisions and active development on the project to alleviate chat context memory issues. This document should follow the following format and should like to the GitHub issue where applicable:

## In Progress
`- [ ] Task name - Started yyy-mm-dd - brief context`
- [ ] Add multus and revise qbit deployment - **Impact:** Better network isolation for qBittorrent; simplifies deployment (See [#1168](https://github.com/tscibilia/home-ops/issues/1168))
- [ ] Add autobrr and thelounge - (See [#803](https://github.com/tscibilia/home-ops/issues/803))
- [ ] Add cluster documenation - (See [#1210](https://github.com/tscibilia/home-ops/issues/1210))
- [ ] Upgrade postgres16 to 17 or 18 - (See [#1211](https://github.com/tscibilia/home-ops/issues/1211))

## Known Issues
`- Task name - impact & workaround`
- Unpoller not workingm thought it was a similar Go 1.23 issue like unifi-dns **Investigate more**
- Document issues with bootstrapping ([#1252](https://github.com/tscibilia/home-ops/issues/1252)) - **update talos machineconfig and VM NIC**
  - [ ] Resolve `just talos render-config <node>` not getting the right talos image
  - [ ] Resolve `akeyless-inject.sh` info logs being put into the render-config
  - [ ] Consider adding bootstrap recipe to pipe `rook-external-import.sh` with `just template`
- Add multus and revise qbit deployment ([#1168](https://github.com/tscibilia/home-ops/issues/1168)) - **update talos machineconfig and VM NIC**

## Blocked
`- Task name - blocking factor (waiting for X)`
- ⚠️ Add multus and revise qbit deployment ([#1168](https://github.com/tscibilia/home-ops/issues/1168)) - **UDM-Pro VLAN and Proxmox setup**
###  [Pending Milestone](https://github.com/tscibilia/home-ops/milestone/1)
- ⚠️ Migrate from minio to Garage/OpenMaxIO - (See [#842](https://github.com/tscibilia/home-ops/issues/842)) - **waiting on upstream project development**
- ⚠️ Migrate from ytptube to hometube - (See [#849](https://github.com/tscibilia/home-ops/issues/849)) - **Doesn't yet support playlist downloads**
- ⚠️ Add homebox - (See [#85](https://github.com/tscibilia/home-ops/issues/85)) - **Doesn't yet support OIDC**

## Resolved
`Descending order, newest on top`
- ✅ VMAgent Scrape Pool Target Discovery Issues - **2025-12-09** (See [#1261](https://github.com/tscibilia/home-ops/issues/1261))
- ✅ Tailscale Split DNS after unifi-dns Migration - **2025-12-04** (See [#1235](https://github.com/tscibilia/home-ops/issues/1235))
- ✅ Jellyfin 10.11.x trickplay path changed - **2025-12-04** (See [#1234](https://github.com/tscibilia/home-ops/issues/1234))
- ✅ Switch from k8s-gateway -> unifi-dns - **2025-12-04** (See [#1229](https://github.com/tscibilia/home-ops/issues/1229))
- ✅ Fix Plex & allow remote access - **2025-12-03** (See [#1227](https://github.com/tscibilia/home-ops/issues/1227))
- ✅ Add guacamole container - **2025-11-29** (See [#524](https://github.com/tscibilia/home-ops/issues/524))
- ✅ Authentik Application Icons Not Displaying from MinIO S3 - **2025-11-28** (See [#1197](https://github.com/tscibilia/home-ops/issues/1197))
- ✅ Internal Apps Inaccessible from LAN - **2025-11-28** (See PR [#1194](https://github.com/tscibilia/home-ops/pull/1194) & issue [#1196](https://github.com/tscibilia/home-ops/issues/1196))
- ✅ Cloudflared tunnel connection error - **2025-11-27** (See commit [db25bb3](https://github.com/tscibilia/home-ops/commit/db25bb3) & issue [#1189](https://github.com/tscibilia/home-ops/issues/1189))
- ✅ Update bootstrap and talos config - **2025-11-23** (See PR [#1173](https://github.com/tscibilia/home-ops/pull/1173) & issue [#804](https://github.com/tscibilia/home-ops/issues/804))
- ✅ Jellyseerr to Seerr Migration - **2025-11-20** (See commit[fbb9ecf](https://github.com/tscibilia/home-ops/commit/fbb9ecf) & [`seerr/README.md`](../kubernetes/apps/media/seerr/README.md))
- ✅ Grafana Operator Migration - **2025-11-19** (See PR [#1157](https://github.com/tscibilia/home-ops/pull/1157))
- ✅ HTTPRoute instead of Ingress - **2025-11-13** (See PR [#1097](https://github.com/tscibilia/home-ops/pull/1097) & issue [#523](https://github.com/tscibilia/home-ops/issues/523))

## Unresolved
- ⛔ Migrate vaultwarden to postgres (See [#1212](https://github.com/tscibilia/home-ops/issues/1212)) - **2025-12-01 Not Planned, sqlite is acceptable <10 users**
- ⛔ Migrate unifi aws to cluster (See issue [#802](https://github.com/tscibilia/home-ops/issues/802)) - **2025-11-17 Failed due to UDP & Cloudflare**
