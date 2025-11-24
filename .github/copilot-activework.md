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
- Verify NAS_IP to nas.internal migration for monitoring - Swapped NFS mounts to `nas.internal`, but need to verify these still work:
  - `kubernetes/apps/observability/exporters/snmp-exporter/synology/helmrelease.yaml` - SNMP target
  - `kubernetes/apps/observability/exporters/snmp-exporter/synology/prometheusrule.yaml` - Prometheus instance match
  - `kubernetes/apps/observability/exporters/blackbox-exporter/app/probes.yaml` - ICMP ping & port 2049 check (NAS & Unraid)
  - `kubernetes/apps/network/externalsecret.yaml` - SYNO_IP for Synology DDNS updater (may require IP)
- Verify UNRAID_IP to unraid.internal migration - Swapped NFS mounts, but need to verify:
  - `kubernetes/apps/default/homepage/app/configmap.yaml` - host for widgets & href links (lines 26, 185, 190)

## Blocked
`- Task name - blocking factor (waiting for X)`
- Add multus and revise qbit deployment ([#1168](https://github.com/tscibilia/home-ops/issues/1168)) - UDM-Pro VLAN and Proxmox setup

## Resolved
`Descending order, newest on top`
- ✅ Update bootstrap and talos config - (See PR [#1173](https://github.com/tscibilia/home-ops/pull/1173) & issue [#804](https://github.com/tscibilia/home-ops/issues/804))
- ✅ Jellyseerr to Seerr Migration - 2025-11-20 (See commit[fbb9ecf](https://github.com/tscibilia/home-ops/commit/fbb9ecf927855b748dc9586188f91a0c89a04f9c) & [`seerr/README.md`](../kubernetes/apps/media/seerr/README.md))
- ✅ Grafana Operator Migration - 2025-11-19 (See PR [#1157](https://github.com/tscibilia/home-ops/pull/1157))
- ✅ HTTPRoute instead of Ingress - 2025-11-13 (See PR [#1097](https://github.com/tscibilia/home-ops/pull/1097) & issue [#523](https://github.com/tscibilia/home-ops/issues/523))

## Unresolved
- ⛔ Migrate unifi aws to cluster  - 2025-11-17 (Failed due to UDP & Cloudflare, see issue [#802](https://github.com/tscibilia/home-ops/issues/802))
