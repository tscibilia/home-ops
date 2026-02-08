# Active Work & Known Issues

This document is intended to supplement and connect with GitHub issues and meant to provide AI agents with context regarding planned revisions and active development on the project to alleviate chat context memory issues. This document should follow the following format and should like to the GitHub issue where applicable:

## In Progress
`- [ ] Task name - Started yyy-mm-dd - brief context`
- [ ] Migrate from ytptube to hometube - (See [#849](https://github.com/tscibilia/home-ops/issues/849))

## Known Issues
- etcd noisy logging, see kubernetes/kubernetes/issues/#134080 - **lookup localhost: operation was canceled**
- talos 1.12 introduced OOM bug siderolabs/talos/issues/#12526 - **added config fix in commit [8efe556](https://github.com/tscibilia/home-ops/commit/8efe556)**
- tuppr not self-updating, see home-operations/tuppr/issues/#65 - **token might not be regenerating**
- snmp-exporter synology, too many scrape errors - **snmpget hangs and timing out, disabled [7f0150f7]**

## Blocked
`- Task name - blocking factor (waiting for X)`
- ⚠️ Envoy 1.7.0 breaks ext-auth - (See [#1619](https://github.com/tscibilia/home-ops/pull/1619)) - **waiting on upstream changes**
###  [Pending Milestone](https://github.com/tscibilia/home-ops/milestone/1)
- ⚠️ Migrate from minio to Garage - (See [#842](https://github.com/tscibilia/home-ops/issues/842)) - **waiting on upstream project development**

## Resolved
`Descending order, newest on top`
- ✅ Fix unifi/qbit port forwarding - **2026-01-28** (See issue [#1551](https://github.com/tscibilia/home-ops/issues/1551))
- ✅ Add autobrr and thelounge - **2026-01-08** (See PR [#1440](https://github.com/tscibilia/home-ops/pull/1440) & [#1442](https://github.com/tscibilia/home-ops/pull/1442) as well as issue [#803](https://github.com/tscibilia/home-ops/issues/803))
- ✅ Remove sops - **2026-01-06** (See PR [#1431](https://github.com/tscibilia/home-ops/pull/1431))
- ✅ Add homebox - **2026-01-04:** (See PR [#1409](https://github.com/tscibilia/home-ops/pull/1409) & issue [#85](https://github.com/tscibilia/home-ops/issues/85))
- ✅ Upgrade postgres16 to 17 - **2025-12-29:** (See commit [b293ff1](https://github.com/tscibilia/home-ops/commit/b293ff1) & issue [#1211](https://github.com/tscibilia/home-ops/issues/1211))
- ✅ Add multus and revise qbit deployment - **2025-12-29:** (See PR [#1337](https://github.com/tscibilia/home-ops/pull/1337) & issue [#1168](https://github.com/tscibilia/home-ops/issues/1168))
- ✅ Add cluster documentation - **2025-12-15** (See PR [#1303](https://github.com/tscibilia/home-ops/pull/1303) & issue [#1210](https://github.com/tscibilia/home-ops/issues/1210))
- ✅ Document issues with bootstrapping - **2025-12-14** ([#1252](https://github.com/tscibilia/home-ops/issues/1252))
- ✅ Unpoller (MTU & config issue) - **2025-12-14** (See commit [06b6686](https://github.com/tscibilia/home-ops/commit/06b6686) & issue kashalls/external-dns-unifi-webhook/issues/163)
- ✅ VMAgent Scrape Pool Target Discovery Issues - **2025-12-09** (See [#1261](https://github.com/tscibilia/home-ops/issues/1261))
- ✅ Tailscale Split DNS after unifi-dns Migration - **2025-12-04** (See [#1235](https://github.com/tscibilia/home-ops/issues/1235))
- ✅ Jellyfin 10.11.x trickplay path changed - **2025-12-04** (See [#1234](https://github.com/tscibilia/home-ops/issues/1234))
- ✅ Switch from k8s-gateway -> unifi-dns - **2025-12-04** (See PR [#1228](https://github.com/tscibilia/home-ops/pull/1228) & issue [#1229](https://github.com/tscibilia/home-ops/issues/1229))
- ✅ Fix Plex & allow remote access - **2025-12-03** (See [#1227](https://github.com/tscibilia/home-ops/issues/1227))
- ✅ Add guacamole container - **2025-11-29** (See PR [#1198](https://github.com/tscibilia/home-ops/pull/1198) & issue [#524](https://github.com/tscibilia/home-ops/issues/524))
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
