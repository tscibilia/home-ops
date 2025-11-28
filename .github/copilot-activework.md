# Active Work & Known Issues

This document is intended to supplement and connect with GitHub issues and meant to provide AI agents with context regarding planned revisions and active development on the project to alleviate chat context memory issues. This document should follow the following format and should like to the GitHub issue where applicable:

## In Progress
`- [ ] Task name - Started yyy-mm-dd - brief context`
- [ ] Add multus and revise qbit deployment - **Impact:** Better network isolation for qBittorrent; simplifies deployment (See [#1168](https://github.com/tscibilia/home-ops/issues/1168))
- [ ] Migrate from ytptube to hometube - (See [#849](https://github.com/tscibilia/home-ops/issues/849))
- [ ] Migrate from minio to Garage/OpenMaxIO - (See [#842](https://github.com/tscibilia/home-ops/issues/842))
- [ ] Add autobrr and thelounge - (See [#803](https://github.com/tscibilia/home-ops/issues/803))

## Known Issues
`- Task name - impact & workaround`
- Add multus and revise qbit deployment ([#1168](https://github.com/tscibilia/home-ops/issues/1168)) - update talos machineconfig and VM NIC

## Blocked
`- Task name - blocking factor (waiting for X)`
- Add multus and revise qbit deployment ([#1168](https://github.com/tscibilia/home-ops/issues/1168)) - UDM-Pro VLAN and Proxmox setup

## Resolved
`Descending order, newest on top`
- ✅ Internal Apps Inaccessible from LAN - 2025-11-28 (See PR [#1194](https://github.com/tscibilia/home-ops/pull/1194) & issue [#1196](https://github.com/tscibilia/home-ops/issues/1196))
- ✅ Cloudflared tunnel connection error - 2025-11-27 (See commit [db25bb3](https://github.com/tscibilia/home-ops/commit/db25bb3) & issue [#1189](https://github.com/tscibilia/home-ops/issues/1189))
- ✅ Update bootstrap and talos config - (See PR [#1173](https://github.com/tscibilia/home-ops/pull/1173) & issue [#804](https://github.com/tscibilia/home-ops/issues/804))
- ✅ Jellyseerr to Seerr Migration - 2025-11-20 (See commit[fbb9ecf](https://github.com/tscibilia/home-ops/commit/fbb9ecf) & [`seerr/README.md`](../kubernetes/apps/media/seerr/README.md))
- ✅ Grafana Operator Migration - 2025-11-19 (See PR [#1157](https://github.com/tscibilia/home-ops/pull/1157))
- ✅ HTTPRoute instead of Ingress - 2025-11-13 (See PR [#1097](https://github.com/tscibilia/home-ops/pull/1097) & issue [#523](https://github.com/tscibilia/home-ops/issues/523))

## Unresolved
- ⛔ Migrate unifi aws to cluster  - 2025-11-17 (Failed due to UDP & Cloudflare, see issue [#802](https://github.com/tscibilia/home-ops/issues/802))
