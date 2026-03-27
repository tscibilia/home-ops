# Observability

Namespace: `observability`

| App                    | Storage          | Notes                                    |
| ---------------------- | ---------------- | ---------------------------------------- |
| kube-prometheus-stack  | ceph-ssd         | Prometheus + Alertmanager, core of monitoring |
| grafana                | —                | Dashboards, Postgres for storage         |
| gatus                  | —                | Uptime monitoring, Postgres (cnpg), external access |
| victoria-logs          | openebs-hostpath | Log aggregation, ext-auth-internal       |
| fluent-bit             | —                | Log shipper → victoria-logs              |
| kite                   | —                | Postgres (cnpg component)                |
| guacamole              | —                | Remote desktop gateway, Postgres         |
| scrutiny               | —                | Disk health hub — collectors on docker machines report here |
| karma                  | —                | Alertmanager UI, depends on kube-prometheus-stack |
| kromgo                 | —                | Badge/status API, external access, depends on kube-prometheus-stack |
| unpoller               | —                | UniFi metrics exporter, depends on kube-prometheus-stack |
| exporters              | —                | SNMP, blackbox, and other Prometheus exporters |
| silence-operator       | —                | Auto-silences for maintenance windows    |
| keda                   | —                | Cluster-wide autoscaler (lives here, used by many namespaces) |

## Config Notes

??? note "Scrutiny"
    Hub-and-spoke setup. The hub runs in this namespace as a Kubernetes pod. Collectors run as Docker containers on each external machine (TrueNAS, UnRaid, AI3090) and report disk SMART data back to the hub. See [Docker Services](../docker/) for the collector configs.

??? note "victoria-logs"
    Uses `openebs-hostpath` for local fast storage (write-heavy log ingestion). Protected by ext-auth-internal for web UI access. Fluent-bit ships logs from all pods into victoria-logs.

??? note "KEDA"
    The autoscaler itself lives in observability, but its ScaledObjects are used across media and default namespaces via the `keda` component. Apps with `keda/nfs-scaler` scale based on NFS mount availability.

??? note "Grafana"
    Uses Postgres (in the database namespace) for dashboard and user storage. No dedicated PVC — state is in the database.
