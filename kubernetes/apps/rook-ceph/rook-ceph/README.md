# Rook Ceph
I took it as a challenge to materialize [onedr0p's idea](https://onedr0p.github.io/home-ops/archive/proxmox-considerations.html) to have an external Ceph cluster for my virtualized cluster to consume. It's was by no means a simple endeavor. In my reasearch phase, I found more who started but abanonded external rook-ceph in favor of bare-metal. I must credit [Frantathefranta](https://github.com/frantathefranta/home-ops/) for most of their configurations, I couldn't have done it without that repo (and chatGPT).

## External cluster
### Specifications
| Item      | Description                                                             |
| --------: | :---------------------------------------------------------------------- |
| *Server*  | (3) Dell R620                                                           |
| *Network* | Dell 10GbE Dual-port cards in a mesh configuration, 10Gb public network |
| *OSDs*    | (4) 900GB 10k SAS drives in each server                                 |

### Prerequisites
I set up my external cluster on [Proxmox](https://pve.proxmox.com/wiki/Deploy_Hyper-Converged_Ceph_Cluster). Refer to my post-setup troubleshooting below, but here's some foreshadowing: read and understand it prior to starting.

### Running the `create-external-cluster-resources.py` script
The command I ran on my Proxmox node looked like this:
```bash
$ python3 create-external-cluster-resources.py --rbd-data-pool-name ceph-vm  --namespace rook-ceph-external --format bash --monitoring-endpoint 10.10.10.1  --cephfs-filesystem-name ceph-fs --ceph-conf /etc/pve/ceph.conf --v2-port-enable --output rook-ceph.env
```
*NOTE* I didnt use RGW Object store and that's good enough for me, but you can follow [Frantathefranta's documentation](https://github.com/frantathefranta/home-ops/) to attempt it.

## Kubernetes steps
### Running the `import-external-cluster.sh` script
When your `operator` and `cluster` HelmReleases are deployed, you can run this script. Here's some tips:
 1. Make sure that you have the right `OPERATOR_NAMESPACE` env var set in the script. If this is set wrong, your provisioner will be named wrong and your PVCs will not start provisioning.
 2. Make sure the `export ARGS` block is included in the env variables to export to the local workstation that your using to connect to your cluster.
 3. Make sure to include `export SUBVOLUME_GROUP=<your-subvolume>` in the variables. See my post-install troubleshooting to grab this from Proxmox.
 4. You can select how these secrets get populated with values, I chose to add them all to my exernal-secrets provider, I used some in this configuration but it was for a future attempt at automating the boostrap process.

### Cluster verification
 - Make sure to verify the cluster and the storageclass is available by running:
```bash
kubectl -n rook-ceph get cephcluster
kubectl -n rook-ceph get sc
```
 - Create a PVC (one for each storageclass, I wasn't able to create one on `cephfs` but `ceph-rbd` was ok).

## Post-setup Troubleshooting
### Missing subvolumegroup
- It seems the `import-external-cluster.sh` or my export env variables from the `create-external-cluster-resources.py` script was missing a subvolumegroup variable.
- On Proxmox I ran `ceph fs subvolumegroup ls ceph-fs` and the output told me the subvolumegroup was `csi`.
- I added the env variable `SUBVOLUME_GROUP=csi` to the import script and re-ran it.

### Incorrect provisioner permissions
- It seems I could create PVCs for `ceph-rdb` but not `ceph-fs`, after some chatgpt troubleshooting the logs I found this error: `rados: ret=-1, Operation not permitted`.
- I was told to fix the permissions in Proxmox with this command:
```bash
ceph auth caps client.csi-cephfs-provisioner \
  mon "allow r, allow command 'osd blocklist'" \
  mgr "allow rw" \
  mds "allow *" \
  osd "allow rw pool=ceph-fs_metadata, allow rw pool=ceph-fs_data"
```
- Then I was told to delete the pods with these commands:
```bash
kubectl -n rook-ceph delete pod -l app=csi-cephfsplugin
kubectl -n rook-ceph delete pod -l app=csi-provisioner
```
- While they were redeploying, I tested that the provisioner could now write to ceph-fs with this command:
```bash
echo "rook test" > /tmp/ceph-testfile && rados -p ceph-fs_metadata \
  --id csi-cephfs-provisioner \
  --key <your-key-here> \
  put testfile /tmp/ceph-testfile
```
- This returned back to the command line without error so I jumped back into Kubernetes and tested a cephfs PVC, and to my amazement it worked!

### Unreachable Network
One other gotcha is that when you use the [Full Mesh Network](https://pve.proxmox.com/wiki/Full_Mesh_Network_for_Ceph_Server), you'll need to be careful that the `public_network` in `ceph.conf` is set to a reachable network for your Kubernetes cluster. If it's not, you'll run into weird issues that are more difficult to diagnose. Since I established my Ceph network separately in a [Broadcast Setup](https://pve.proxmox.com/wiki/Full_Mesh_Network_for_Ceph_Server#Broadcast_Setup), I was able to just add a second NIC to my Talos nodes that was `vmbr1` and updated my talos node configs to assign an IP to it (since it's not managed by a network switch).

### Prometheus TargetDown 'rook-ceph-mgr-external'
After installing VictoriaMetrics (or Prometheus), I saw the general.rules firing an alert that 2/3 of my `mgr` were down. I thought this is because I declared all 3 as potential managers and there's only 1 at a time, it turns out that vmagent was scrapping based on the svc/rook-ceph-mgr-external and endpoints. I was able to "resolve" it by removing the default monitoring and prometheus settings in helmrelease.yaml and establishing [a custom rule](https://github.com/tscibilia/home-ops/blob/458c6aa923a31bfd9ec505a3d58f2b1b843c6da3/kubernetes/apps/rook-ceph/rook-ceph/cluster/prometheusrule.yaml#L527) that just checks for 1 mgr as well as a [custom scrape](https://github.com/tscibilia/home-ops/blob/458c6aa923a31bfd9ec505a3d58f2b1b843c6da3/kubernetes/apps/observability/victoria-metrics/stack/secret.yaml#L8) that was applied to [victoria-metrics/stack/helmrelease.yaml > spec.values.vmagent](https://github.com/tscibilia/home-ops/blob/458c6aa923a31bfd9ec505a3d58f2b1b843c6da3/kubernetes/apps/observability/victoria-metrics/stack/helmrelease.yaml#L184)

### Bluestore slowops warnings
I'm often getting Bluestore slowops warnings. Hopefully the pending upgrade to faster SSDs will get rid of this issue. However, in the interim, I found that Proxmox defaluts to a long 24hr warning if there is but a single slowops warning. So, in Proxmox, I set `ceph config set osd bluestore_slow_ops_warn_lifetime 300 ` and `ceph config set osd bluestore_slow_ops_warn_threshold 5`. Ceph was only warning me if a single BlueStore op stayed stuck for a whole day. Now, I should get alerted if there’s a persistent backlog, but you not get spammed by transient latency.

## Improvements for future me
### Made an attempt at automating
I might try setting up the following yamls so I don't need to run `import-external-cluster.sh` on each bootstrap:
 - `rbd-secrets.yaml`
 - `cephfs-secrets.yaml`
 - `storageclass.yaml`
 - `monitor-config.yaml`

### Resources
 - [#external-rook-ceph discord](https://discord.com/channels/673534664354430999/1023423088563597322)
 - [frantathefranta/home-ops](https://github.com/frantathefranta/home-ops/tree/main/kubernetes/apps/rook-ceph-external/rook-ceph) using external ceph, biggest resource for me
 - [billm/moria-ops](https://github.com/billm/moria-ops/blob/main/kubernetes/moria/apps/storage/rook-ceph/cluster/helmrelease.yaml) using external ceph, good configs
 - [dcplaya/home-ops](https://github.com/dcplaya/home-ops/tree/main/kubernetes/apps/rook-ceph/rook-ceph) no longer using external ceph, but referenced from discord
 - [Official Docs](https://rook.io/docs/rook/latest-release/CRDs/Cluster/external-cluster/external-cluster/)
