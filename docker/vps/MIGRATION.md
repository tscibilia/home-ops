# Pangolin to towonel Migration Guide

Migration reference from Pangolin (Traefik + WireGuard) to towonel (SNI
passthrough over iroh QUIC) for public ingress.

## Status

✅ Migration completed August 2026

Model: Opus 5 | Context: [████████░░░░░░░░] 477k/1.0M (48%) | Cost: $227.65

The live architecture, stack list and secret map are in [`README.md`](README.md).
This document covers why the move happened, how it was sequenced, and what went
wrong along the way.

## Why We Moved

This migration improved your security posture. Pangolin terminated TLS on the VPS,
it held certs and saw all request in plaintext. That fact caused three problems:

1. The tunnel operator held a valid private key for every hostname. Any traffic
   between the VPS and the cluster was decrypted and re-encrypted by software we
   did not control.

2. Cloudflare's proxy sat in front, so request bodies were capped at 100 MB.
   Uploads to Immich and similar apps failed above that.

3. Client IPs arrived through two proxy hops, the second being the `newt` pod.
   `X-Forwarded-For` read `157.230.51.94,10.42.0.75`, so apps that trusted the
   last hop saw a pod IP.

[towonel](https://towonel.dev/) solves all three by never decrypting. `caddy-l4` reads the TLS SNI to
decide where a connection goes, then forwards the raw bytes. TLS terminates at
`envoy-external` inside the cluster, where the certificate already lives.
Through towonel the same request yields a single clean hop: `100.35.75.195`.

## Architecture Comparison

### Before (Pangolin)

```
Internet → Cloudflare (proxied) → VPS:443 → Traefik (terminates TLS)
         → Pangolin → newt pod (WireGuard) → envoy-external → App
```

### After (towonel)

```
Internet → DNS-only → VPS:443 → caddy-l4 (SNI split, no decrypt)
         → towonel edge → iroh QUIC 51820/udp → towonel agent
         → envoy-external (terminates TLS) → App
```

**Key Changes:**

- TLS terminates in the cluster, not on the VPS
- DNS records are DNS-only, not Cloudflare-proxied, so no 100 MB body cap
- Client IP arrives in one hop via PROXY v2 and `trustedCIDRs`
- The agent dials out from the cluster; no inbound port to the LAN
- `caddy-l4` terminates TLS for two hostnames only — the towonel hub and the
  UniFi controller UI
- Stack directories are numbered by dependency order, `01-caddy-l4` first

## Migration Sequence

The work ran as ten tasks against a written spec, each implemented by a fresh
subagent and reviewed before the next began. Gates A–F were the points where a
human had to confirm reality before work continued.

### Phase 1 — Build the new path beside the old (Tasks 1–5)

Pangolin kept serving throughout. The towonel hub, the `caddy-l4` SNI splitter
and the host playbook were authored and validated offline, then deployed to a
temporary DigitalOcean droplet. The in-cluster agent and the observability stack
followed.

Two plan defects surfaced here. `caddy-l4` had been scheduled far too late, so
it was promoted to its own task. The host directory layout then had to be split
in a corrective task once it became clear the droplet and the permanent VPS
needed separate trees. Task 3 took four fix rounds, mostly on the geo-block
script's failure modes.

### Phase 2 — Validate without touching DNS (Task 6)

The plan called for a single-hostname DNS canary using
`external-dns.alpha.kubernetes.io/target` on one HTTPRoute. It does not work —
external-dns ignores the per-route annotation and the Gateway's annotation
always wins. Two `cetranscript` routes had carried ineffective annotations for
as long as they had existed.

The replacement was better than the original plan:

```bash
curl --resolve echo.t0m.co:443:<vps-ip> https://echo.t0m.co
```

This forces the connection to the towonel edge while presenting real SNI. It
exercises the whole path with no DNS change, no propagation delay and no blast
radius. Every external hostname was then probed twice — once forced through
towonel, once straight to `envoy-external` on the LAN. **19 of 19 matched** on
both status code and redirect target.

That result is what made the cutover a formality: the data path was already
carrying every hostname correctly. Only DNS had not moved.

### Phase 3 — DNS cutover (Task 7)

Ownership of `external.*` moved from Pangolin to the towonel agent's
DNSEndpoint. The gap was **7 seconds** and no pod restarted.

An early verification looked wrong because LAN split-horizon DNS resolved the
probes to `envoy-external` directly, bypassing the VPS entirely. Verification
had to be repeated from an off-LAN host. The UDM-Pro also hijacks port 53, so
DNS-over-HTTPS was needed to see public answers.

A soak period followed (Gate E) with no app downtime observed.

### Phase 4 — Port the build to the permanent VPS (Task 8)

The droplet was always temporary. Task 8 ported the whole host build onto the
permanent RackNerd VPS, adding the UniFi controller and its backup stack. Three
fix rounds; the implementer correctly rejected one false premise in the brief
and found a third file affected by the same bug the review had caught twice.

### Phase 5 — Consolidation (Gate F)

This is where it got expensive. Two attempts, roughly ten minutes of total
downtime.

**Attempt 1 failed.** DNS moved correctly; nothing served. Two blockers, and
both initial diagnoses were wrong.

The real blocker was that the new hub had **no invite at all**. The spec claimed
that copying the five hub secrets made it "the same hub". It does not. Those
keys cover signing and authentication only — registrations, claimed invites,
tenants and the route table live in `/opt/towonel/hub.db` and do not travel.
The follow-up guess, that the agent would simply re-enrol, was also wrong;
`/v1/invites` returned zero.

The second reported blocker — that ACME could not complete without port 80 —
was simply false. The host already held a real Let's Encrypt certificate issued
via TLS-ALPN-01 with no `:80` published. One `ls /data/caddy/certificates`
would have shown that before a fix was proposed.

**Attempt 2 succeeded** after minting a fresh invite on the new hub and adding a
pre-flight gate: verify both aKeyless values before forcing anything. It still
cost six minutes, because Caddy made **no ACME attempts for over four minutes**.
It was in exponential backoff from attempt 1, and an empty log looked like "not
started yet". `docker restart caddy-l4` cleared it and the certificate issued in
about 20 seconds.

Discovered mid-attempt: the droplet's sshd had died and both `:22` and `:22222`
refused connections, while `:443` served normally. The provider console reaches
the droplet over SSH rather than out-of-band, so it hung too. Production was
running on a host nobody could administer. That turned finishing Gate F from a
risk into a risk _reduction_.

All 19 hostnames were re-verified from off-LAN against the pre-migration
baseline.

### Phase 6 — Retire Pangolin (Task 9)

The Docker half shipped first: `01-pangolin` archived, seven external secrets
removed. The Kubernetes half removed `pangolin-operator`, its `NewtSite`, its
ExternalSecret and the `tun.`, `api.tun.` and `doco.tun.` records.

One defect: the operator and its custom resources were deleted in the same
commit, which orphaned a finalizer only that operator could clear. The
Kustomization hung until the finalizer was patched by hand.

The hub kept the `twnl.` hostname. Renaming it to `tun.` would have changed the
hub's public URL and the edge's advertised address, required a fresh
certificate that cannot be pre-issued, and probably needed a new invite — a full
repeat of Gate F for a shorter name.

### Phase 7 — Converge Ansible (Task 10)

Two playbooks existed: one named for the droplet, one named for the permanent
VPS that still bootstrapped Pangolin. Task 10 merged them into one, collapsed
the inventory, and deleted the droplet's Docker tree.

**The first attempt was wrong and the operator caught it.** The convergence went
in the wrong direction: it kept the droplet's playbook and renamed it onto the
permanent VPS's path. `git diff --stat` renders that as an edit, so neither the
implementer nor the reviewer saw that every droplet-shaped decision had been
carried onto production — including the wrong SSH public key, which would have
locked the operator out on the next bootstrap, and a `NOPASSWD` sudoers
drop-in that had been explicitly rejected.

The lesson generalises: **when a change renames file A onto path B and deletes
B, the review baseline is the old B, never A.**

### Phase 8 — Harden (CrowdSec)

CrowdSec runs as a containerised engine with the firewall bouncer installed on
the host by Ansible. Both reference implementations we compared use this split,
and the reason is concrete: the bouncer must be on the host to write `iptables`,
and it writes into `DOCKER-USER`, the only chain that filters published
container ports.

Four defects were found and fixed during this phase, listed under Common Issues
below. Reusing the retired Traefik bouncer's API key was the most instructive —
the CrowdSec state directory had survived from the Pangolin era, so that key was
already bound to old registrations and the new bouncer inherited the wrong
identity.

## Key Decisions

| Decision                           | Reason                                                                |
| ---------------------------------- | --------------------------------------------------------------------- |
| TLS passthrough, not termination   | The whole point — keeps the private key in the cluster                |
| DNS-only, never Cloudflare-proxied | Proxying re-terminates TLS and restores the 100 MB cap                |
| Keep the `twnl.` hostname          | Renaming repeats the Gate F cutover for no functional gain            |
| Escalate with `su`, not `sudo`     | The `ubuntu` account is passwordless by design; `root` has a password |
| Containerised engine, host bouncer | Only a host process can write `iptables`                              |
| Numbered stack directories         | Dependency order; `caddy-l4` owns `:443` and must start first         |
| One playbook, one inventory host   | A rebuilt VPS should need no flags anyone has to remember             |

## Common Issues

### doco-cd destroys a renamed stack directory

doco-cd tracks stacks by directory name, not by the compose `name:` field.
Renaming one makes it log `removing obsolete auto-discovered stack`, tear the
old stack down, then deploy the new one. Renumbering the five VPS stacks cost
about 90 seconds of full ingress downtime.

Rename directories in a commit of their own, and expect an outage. Data
survives because each stack uses `/opt/<app>` bind mounts or named volumes.

### doco-cd ignores an inline config change

doco-cd does not recreate a container when only a `configs:` `content:` block
changes. The Prometheus scrape config shipped correct YAML that never reached
the running container, and Grafana showed empty towonel panels for a day.

Fix with `docker rm -f <container>`; doco-cd redeploys it on the `die` event.

### doco-cd has no webhook

It polls hourly and has no force-deploy API. To reconcile immediately:

```bash
just ansible restart-doco-cd vps
```

### Caddy stops trying ACME and says nothing

Absence of ACME log lines means backoff, not failure. After any failed cutover,
restart `caddy-l4` before judging whether ACME works.

```bash
docker logs caddy-l4 --since=10m | grep -i acme   # empty = backoff
docker restart caddy-l4
```

Note that `caddy-l4` ships no DNS-01 provider, so a certificate can never be
pre-issued before a DNS move. Some certless window at cutover is unavoidable.

### towonel hub state does not travel with the keys

Copying the five hub secrets does not move registrations, invites or the route
table — those live in `/opt/towonel/hub.db`. Mint a new invite on the new hub
with the same name and hostnames.

Both hosts report the same edge id because they share the identity key, so the
edge id cannot tell you which host the agent reached.

### The agent restarts the instant its secret syncs

The agent HelmRelease carries `reloader.stakater.com/auto: "true"`. If the
invite token changes while DNS still points at the old host, the agent
bootstraps against the old hub with a token that hub does not know. Run these
back to back with no delay:

```bash
just kube sync es network towonel-agent-secret
flux reconcile ks towonel-agent-config -n network
```

`towonel-agent-secret` is the ExternalSecret; `towonel-agent-config` is the Flux
Kustomization. The names are not interchangeable.

### Published container ports bypass ufw

Published ports traverse `PREROUTING → FORWARD → DOCKER` and never reach
`INPUT`, so `ufw status` can look correct while a port answers from the
internet. Bind `127.0.0.1` for host-only services. `DOCKER-USER` is the only
chain that filters container traffic.

Also, ufw never prunes: removing a port from the Ansible loop does not remove
the rule from the host. Delete by rule so v4 and v6 both go and numbering does
not shift:

```bash
ufw delete allow 80/tcp
```

### Ansible fails with "Timeout waiting for privilege escalation prompt"

The run is missing `-K`. The prompt wants **root's** password, not `ubuntu`'s.

```bash
just ansible bootstrap-vps -e unifi_host=true -K
```

### external-dns will not adopt an unowned record

With `policy: sync` and a TXT registry, a record without a `k8s.cname-<host>`
TXT is not owned and will not be modified — which is why hand-made proxied
records survived. Deleting the record is the fix, and what happens next depends
on the gateway:

| Hostname claimed by              | Result after deletion                |
| -------------------------------- | ------------------------------------ |
| an HTTPRoute on `envoy-external` | recreated DNS-only in about a minute |
| an app on `envoy-internal`       | stays deleted                        |

external-dns runs with `--gateway-name=envoy-external` only. The second row is
the desired outcome for internal-only apps whose public records advertised
services no external route serves.

### Caddy advertises HTTP/3 that cannot be reached

Only TCP is published to `caddy-l4`, but every HTTP server still advertised
`alt-svc` — `h3=":8443"` behind the layer4 path and `h3=":4443"` on the directly
bound one. Browsers cache that for 30 days and then send requests over UDP that
never arrives, producing `NetworkError` and `NS_BINDING_ABORTED` on XHRs after
the page loads. Pin every server that terminates HTTP:

```caddy
servers :8443 { protocols h1 h2 }
servers :4443 { protocols h1 h2 }
```

The tell is a request the browser reports as failed with **no matching entry in
the Caddy access log at all** — it never arrived. Real HTTP/3 would need
`443/udp` published, opened in ufw, _and_ a UDP route in the `layer4` block,
which is TCP-only; none of that exists, so h1+h2 costs nothing.

A cached `alt-svc` outlives the fix — test in a fresh browser profile.

### UniFi login returned an empty 403

The controller moved to this VPS during Phase 4 and `caddy-l4` terminates TLS
for its vhost. Every browser login answered `403` with an empty `text/plain`
body, while header-free API calls worked.

UniFi rejects a request whose `Origin` does not match its `Host`. That check is
correct — the proxy was breaking it. **Since v2.11.0 Caddy overwrites `Host`
with the upstream address whenever the upstream is `https://`**, to align it
with the TLS ServerName; the client's value survives only in `X-Forwarded-Host`.
The controller serves a self-signed cert, so the upstream must be `https://`,
and UniFi was comparing the browser's `Origin: https://unf.t0m.co` against
`unifi-network-application:8443`.

```caddy
reverse_proxy https://unifi-network-application:8443 {
	header_up Host {http.request.hostport}
	transport http {
		tls_insecure_skip_verify
	}
}
```

To prove it on any host, send a login through the proxy with `Origin` set to the
_upstream_ address — if that is accepted while the real public origin is
refused, `Host` is being rewritten:

```sh
curl -sk -o /dev/null -w '%{http_code}\n' -X POST https://unf.t0m.co/api/login \
  -H 'Content-Type: application/json' -H 'Origin: https://unf.t0m.co' \
  -d '{"username":"x","password":"x"}'
# 400 = Origin accepted and login processed;  403 = Host mismatch
```

Do **not** work around this by stripping `Origin` (`header_up -Origin`). That
suppresses the check instead of fixing the mismatch, and it makes a browser
login look like an API client to the controller — the failure then reappears
downstream as a `401 api.err.LoginRequired` on `GET /api/self` immediately after
a `200` login, which is far harder to trace.

The port is irrelevant to this bug — `header_up Host` keeps `Origin` matching on
whichever port the client used, which is why the vhost can safely serve both
`:443` and `:4443` (see the next section). A `super_identity.hostname` of
`unf.t0m.co` without a port does **not** need to match the published port; that
was a wrong turn during diagnosis, and moving the vhost between ports fixed
nothing on its own.

bjw-s-labs' reference Caddyfile never hits any of this because its upstreams are
plain HTTP, which triggers no `Host` override.

### The UniFi mobile app hangs when the controller is on port 443

The iOS app branches on the **port** when adding a console. On `443` it assumes
a UniFi OS console (UDM, Cloud Key) and probes `/proxy/network/*`. A standalone
Network Application has no such prefix and answers 404, so the add-console
screen spins forever — and sends nothing further, so the server log looks idle
rather than broken.

```sh
curl -sk -o /dev/null -w '%{http_code}\n' https://unf.t0m.co/proxy/network/status
# 404 = standalone Network Application;  200 = real UniFi OS console
```

A non-standard port makes the app use the standalone Network API
(`/status`, `/api/login`, `/api/s/<site>/…`) and it works. The vhost therefore
carries both addresses in one site block, sharing the upstream config:

```caddy
{$UNIFI_HOSTNAME}, {$UNIFI_HOSTNAME}:4443 {
	…
}
```

`:443` is the browser URL and rides the layer4 SNI path; `:4443` binds directly
and is what the app needs. Both were verified to accept a matching `Origin` and
still reject a foreign one.

### CrowdSec sees almost no HTTP

TLS passthrough is the point of the design, so CrowdSec cannot read traffic for
any tunnelled app. It has two sources: `/var/log/auth.log` for sshd, and the
`caddy-l4` container log for the one vhost Caddy does terminate. The
`ban-ai-crawlers` scenario keys off `http_user_agent` and will almost never
fire.

The home allowlist stops CrowdSec **creating** decisions about those ranges. It
does not exempt them from the CAPI community blocklist, and `just ansible unban`
cannot remove a CAPI decision.

### cscli prints JSON with a space after the colon

`"name": "firewall"`, not `"name":"firewall"`. An exact-string grep never
matches, so an idempotency guard re-runs `cscli bouncers add` on every play and
fails once the bouncer exists.

A name-only guard also misses a key rotation. After changing the bouncer key,
run `cscli bouncers delete firewall` first. An unauthenticated bouncer shows an
empty `Last API pull` column.

### The CrowdSec bouncer restart reports a false failure

`crowdsec-firewall-bouncer` is `Type=notify` and signals ready only after
writing every decision into ipset. With tens of thousands of decisions that
overruns systemctl's D-Bus timeout, so a blocking restart reports
`Connection timed out` while the job is still succeeding. The handler starts it
with `--no-block` and polls `systemctl is-active`.

### Deleting an operator and its CRs together orphans finalizers

Only that operator can clear its finalizers, and it is gone. Delete the custom
resources first, let the operator clear them, then remove the operator.
Otherwise:

```bash
kubectl patch <kind> <name> --type=merge -p '{"metadata":{"finalizers":[]}}'
```

## Verifying the Path

Probe from **off-LAN**. Split-horizon DNS resolves several hostnames to
`envoy-external` on the LAN, which bypasses the VPS and proves nothing.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' https://<host>/
```

To test the towonel path without touching DNS at all:

```bash
curl --resolve <host>:443:<vps-ip> https://<host>/
```

A correct result shows the origin's certificate — `issuer=Let's Encrypt`,
`subject=CN = t0m.co` — which is how you confirm passthrough is genuine rather
than re-terminated at the edge.

## References

- [`README.md`](README.md) — live architecture, stacks, secrets, doco-cd behaviour
- [`../../ansible/vps/playbook.yaml`](../../ansible/vps/playbook.yaml) — host build
- [`../../kubernetes/apps/network/towonel-agent/`](../../kubernetes/apps/network/towonel-agent/) — in-cluster agent
- [`../../docs/context/docker-hosts.md`](../../docs/context/docker-hosts.md) — docker host reference
- Full task-by-task record, including every failed attempt: git-ignored
  `.superpowers/sdd/2026-08-06-towonel-migration/`
