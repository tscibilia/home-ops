#+title: Rook Ceph
I took it as a challenge to materialize [[https://onedr0p.github.io/home-ops/notes/proxmox-considerations.html][onedr0p's idea]] to have an external Ceph cluster for my Kubernetes cluster to consume. It's pretty simple surprisingly, but I did run into some hurdles.
* External cluster
** Specifications
| *Server*  | Dell R620                                                               |
| *Network* | Dell 10GbE Dual-port cards in a mesh configuration, 10Gb public network |
| *OSDs*    | 12x 900GB Enterprise SSD in each server                                 |
** Prerequisites
I set up my external cluster on [[https://pve.proxmox.com/wiki/Deploy_Hyper-Converged_Ceph_Cluster][Proxmox]]. One gotcha that I've ran into is that when you use the [[https://pve.proxmox.com/wiki/Full_Mesh_Network_for_Ceph_Server][Full Mesh Network]], you'll need to be careful that the ~public_network~ in ~ceph.conf~ is set to a reachable network for your Kubernetes cluster. If it's not, you'll ran into weird issues that are more difficult to diagnose (at least for me). It's good to check if your CSI provisioners are trying to reach the right endpoints (Cillium Hubble is pretty great for this if you use this CNI).
* Kubernetes steps
** Running the ~create-external-cluster-resources.py~ script
My command looks like this:
#+begin_src sh :noeval
$ python3 create-external-cluster-resources.py --rbd-data-pool-name ceph-vm  --namespace rook-ceph-external --format bash --monitoring-endpoint 10.10.10.1  --cephfs-filesystem-name ceph-fs --v2-port-enable
#+end_src
*** Notes
** Running the ~import-external-cluster.sh~ script
When your ~operator~ and ~cluster~ HelmReleases are deployed, you can run this script. Make sure that you have the right ~OPERATOR_NAMESPACE~ env var set in the script, or export a new env ~CSI_DRIVER_NAME_PREFIX~ if you have a non-standard namespace (like I do). If this is set wrong, your provisioner will be named wrong and your PVCs will not start provisioning.
** Importing the cluster information automatically
Alternatively, if you don't want to run ~import-external-cluster.sh~ on each cluster bootstrap, you can create these files:
 - ~rbd-secrets.yaml~
 - ~cephfs-secrets.yaml~
 - ~storageclass.yaml~
 - ~monitor-config.yaml~

You can select how these secrets get populated with values, I chose to add them to external-secrets.

* Caveats
+Your backups will not be handled by the Kubernetes cluster.+
I figured out you can use ~VolumeSnapshots~ with an external cluster, description WIP.
