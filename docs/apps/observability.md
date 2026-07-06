# Observability

Namespace: `observability`

| App                   | Storage          | Notes                                                                                   |
| --------------------- | ---------------- | --------------------------------------------------------------------------------------- |
| kube-prometheus-stack | ceph-ssd         | Prometheus + Alertmanager, core of monitoring                                           |
| grafana               | —                | Dashboards, Postgres for storage                                                        |
| gatus                 | —                | Uptime monitoring, Postgres (cnpg), external access                                     |
| victoria-logs         | openebs-hostpath | Log aggregation, ext-auth-internal                                                      |
| fluent-bit            | —                | Log shipper → victoria-logs                                                             |
| kite                  | —                | Postgres (cnpg component)                                                               |
| guacamole             | —                | Remote desktop gateway, Postgres                                                        |
| scrutiny              | —                | Disk health hub — collectors on docker machines report here                             |
| karma                 | —                | Alertmanager UI, depends on kube-prometheus-stack                                       |
| kromgo                | —                | Badge/status API, external access, depends on kube-prometheus-stack                     |
| unpoller              | —                | UniFi metrics exporter, depends on kube-prometheus-stack                                |
| exporters             | —                | SNMP, blackbox, NUT UPS, and other Prometheus exporters                                 |
| silence-operator      | —                | Auto-silences for maintenance windows                                                   |
| prometheus-adapter    | —                | External-metrics API for native HPAs (serves `probe_success`); replaced keda 2026-05-17 |

## Config Notes

??? note "Scrutiny"
Hub-and-spoke setup. The hub runs in this namespace as a Kubernetes pod. Collectors run as Docker containers on TrueNAS and CloneNAS and report disk SMART data back to the hub. See [Docker Services](../docker/) for the collector configs.

??? note "victoria-logs"
Uses `openebs-hostpath` for local fast storage (write-heavy log ingestion). Protected by ext-auth-internal for web UI access. Fluent-bit ships logs from all pods into victoria-logs.

??? note "prometheus-adapter (zero-scaling)"
Serves the external metrics API for `probe_success`. Native HPAs in `media`, `default`, and `volsync-system` (via the `zeroscaler` component) query this to scale to 0 when their NFS target is unreachable. Split probes: `jobName: nfs_probe` (truenas) for media/photo apps; `jobName: nfs_bkup_probe` (clonenas) for kopiur/rclone.

??? note "kube-prometheus-stack (remote hosts)"
TrueNAS and CloneNAS run node-exporter (`:9100`) and fluent-bit (`:2020`) scraped directly via ScrapeConfigs. The VPS runs prometheus-agent in agent mode, remote_writing to `prometheus-rw.t0m.co/api/v1/write` (exposed on envoy-external with basic auth). All three hosts ship `container_log_errors_total` and `container_log_warnings_total` counters, triggering the `DocoCdLogErrors` alert.

??? note "NUT exporter"
Scrapes the NUT server on `clonenas.internal` (UPS: `clonenas_ups`). Alerts fire for: on-battery, low runtime (<10 min), low charge (<50%), and battery replacement flag.

??? note "Grafana"
Uses Postgres (in the database namespace) for dashboard and user storage. No dedicated PVC — state is in the database.
