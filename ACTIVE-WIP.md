# Active Work & Known Issues

> This document is intended to supplement and connect with GitHub issues and meant to provide AI agents with context regarding planned revisions and active development on the project to alleviate chat context memory issues. This document should follow the following format and should like to the GitHub issue where applicable:

## In Progress

`- [ ] Task name - Started yyyy-mm-dd - brief context`

- [ ] switch to [home-ops k8s schemas](https://github.com/home-operations/k8s-schemas) - Started **2026-05-18** - PR [#2395](https://github.com/tscibilia/home-ops/pull/2395)
- [ ] switch grafana dashboards from `gnetId` to `URL`

## ⚠️ Known Issues

`- [ ] ⚠️ **App name** - issue (with ref) - **comment**`

- [ ] ⚠️ **Agregarr** follow upstream (issue [#323](https://redirect.github.com/agregarr/agregarr/issues/323)) **integrate with tracearr**
- [ ] ⚠️ **Fairtrail:** Chromium 146 crashes even when run as root (Alpine or Talos issue?) - **Likely abandoning this app**
- [ ] ⚠️ **Donetick:** SSE realtime disconnects through Cloudflare tunnel - **consider trying again with pangolin**
- [ ] ⚠️ **RustFS:** authentik-Admin -> rustfsAdmin, Plex Users need a RustFS group policy for access - **AI assist**

## ⛔ Blocked

`- ⛔ **App name** - blocking factor (waiting for X) - **note**`

- ⛔ **CNPG** upstream bug summarized in issue #2301 causes `scheduledBackups` to get stuck infinitely - **upstream confirmed fix in 1.30.x**
- ⛔ **etcd:** noisy logging, [see upstream](https://redirect.github.com/kubernetes/kubernetes/issues/134080) - **upstream confirmed fix in 1.37**
- ⛔ move github to forgejo - **Unsure of decentralize bootstrap, postponed**

## ✅ Resolved

`Descending order, newest on top`

- ✅ switch to kopiur - **2026-07-05** (see PR [#2863](https://github.com/tscibilia/home-ops/pull/2863) and a bazillion subsequent commits)
- ✅ llama-cpp intermittent `MUL_MAT failed` - **2026-06-25** [see upstream](https://redirect.github.com/ggml-org/llama.cpp/issues/24328)
- ✅ boostrap didn't pick up ai3090 - **2026-06-22** (see commit [4a0af6c2](https://github.com/tscibilia/home-ops/commit/4a0af6c2) and [3266aaca](https://github.com/tscibilia/home-ops/commit/3266aaca))
- ✅ Claude makes dumb mistakes - **2026-06-25** (attempted fix in commit [8075cdf](https://github.com/tscibilia/home-ops/commit/8075cdf))
- ✅ use oxfmt and lefthook - **2026-06-18** (see commit [f10ad6b](https://github.com/tscibilia/home-ops/commit/f10ad6b) and 4 subsequent commits)
- ✅ switch flux-local to konflate - **2026-06-18** (see PR [#2689](https://github.com/tscibilia/home-ops/pull/2689))
- ✅ add kopia to volsync - **2026-05-22** (see commit [4658473](https://github.com/tscibilia/home-ops/commit/4658473) and 4 subsequent commits)
- ✅ LiteLLM installed to manage llm api keys - **2026-05-22** (see PR [#2451](https://github.com/tscibilia/home-ops/pull/2451) and 2 subsequent commits)
- ✅ ComfyUI got 1TB HDD to store nodes and modules - **2026-05-21** (See commit [719f15e](https://github.com/tscibilia/home-ops/commit/719f15e))
- ✅ unifi-network-application restic -> B2 - **2026-05-21** (see commit [00fd5b5](https://github.com/tscibilia/home-ops/commit/00fd5b5))
- ✅ add nut ups monitoring - **2026-05-20** (see PR [#2427](https://github.com/tscibilia/home-ops/pull/2427))
- ✅ add metrics to docker - **2026-05-20** (see PR [#2416](https://github.com/tscibilia/home-ops/pull/2416) and 7 subsequent commits)
- ✅ Cilium L2Announcement -> BGP - **2026-05-19** (see PR [#2398](https://github.com/tscibilia/home-ops/pull/2398))
- ✅ KEDA → native HPA migration - **2026-05-17** (see PR [#2388](https://github.com/tscibilia/home-ops/pull/2388))
- ✅ Rewire network rack with patch cables - **2026-05-16**
- ✅ Cloudflared -> Pangolin switch - **2026-05-16** (see PR [#2383](https://github.com/tscibilia/home-ops/pull/2383))
- ✅ commit [2010ffa](https://github.com/tscibilia/home-ops/commit/2010ffa) resolves rustfs faulty-disk [issue #2686](https://redirect.github.com/rustfs/rustfs/issues/2686) - **2026-05-14**
- ✅ resolved toolhive issues w/ open-webui & opencode - **2026-05-06** (See commit [96019f4](https://github.com/tscibilia/home-ops/commit/96019f4))
- ✅ use [k8tz](https://github.com/k8tz/k8tz) to apply TZ to pods and cronjobs - **2026-05-06** (See [#2276](https://github.com/tscibilia/home-ops/pull/2276))
- ✅ move llama.cpp to cluser - **2026-04-29** (See commit [08dde6f])
- ✅ move ai3090 to talos worker - **2026-04-28** (See [#2201](https://github.com/tscibilia/home-ops/pull/2201) and commit [4a8b97c])
- ✅ ESO remapping/reorganization - **2026-04-07** (See [#2032](https://github.com/tscibilia/home-ops/pull/2032))
- ✅ Migrate minio -> RustFS - **2026-04-07** (See [#842](https://github.com/tscibilia/home-ops/issues/842))
- ✅ NFS `fileid` error w/ volsync - **2026-04-03** (See [#1887](https://github.com/tscibilia/home-ops/issues/1887))
- ✅ Migrate from ytptube to hometube - **2026-03-30** (See [#849](https://github.com/tscibilia/home-ops/issues/849))
- ✅ Fix notifications from grafana alerts - **2026-03-27** (See commit [bde878b](https://github.com/tscibilia/home-ops/commit/bde878b))
- ✅ Docs out of date & needs simplification - **2026-03-26** (See commit [febbc91](https://github.com/tscibilia/home-ops/commit/febbc91))
- ✅ Migrate from synology to truenas - **2026-03-25** (See [#1750](https://github.com/tscibilia/home-ops/issues/1750))
- ✅ Deployed scrutiny hub/spoke on truenas/k8s - **2026-03-18** (See [#1870](https://github.com/tscibilia/home-ops/pull/1870))
- ✅ Envoy 1.7.0 broke ext-auth - **2026-03-16** (See [#1619](https://github.com/tscibilia/home-ops/pull/1619))
- ✅ Migrate HASS from VM to cluster - **2026-02-23** (Added over several commits)
- ✅ rook-ceph metric inaccessible - **2026-02-18** (See issue [#1677](https://github.com/tscibilia/home-ops/issues/1677) & [#1723](https://github.com/tscibilia/home-ops/issues/1723))
- ✅ Migrate VM cluster to bare-metal - **2026-02-12** (See commit [5e8eb98] & issue [#1593])
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

## ❌ Unresolved/Closed

- ❌ Qwen3 thinking enable/disable - **2026-04-03 Not Planned, changed model** [See upstream](https://redirect.github.com/ggml-org/llama.cpp/issues/20182)
- ❌ Synology snmp-exporter too many scrape errors - **2026-02-23 Not Planned, disabled [7f0150f7]**
- ❌ Migrate vaultwarden to postgres (See [#1212](https://github.com/tscibilia/home-ops/issues/1212)) - **2025-12-01 Not Planned, sqlite is acceptable <10 users**
- ❌ Migrate unifi from aws to cluster (See issue [#802](https://github.com/tscibilia/home-ops/issues/802)) - **2025-11-17 Failed due to UDP & Cloudflare, added to VPS**
