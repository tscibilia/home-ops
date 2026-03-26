# Home Automation

Namespace: `home-automation`

| App             | Storage  | Notes                                        |
| --------------- | -------- | -------------------------------------------- |
| home-assistant  | ceph-ssd | Multus networking, external access, volsync  |
| esphome         | ceph-ssd | Multus networking (mDNS device discovery), volsync |
| mosquitto       | ceph-ssd | MQTT broker                                  |
| zwave           | ceph-ssd | USB device passthrough, volsync              |
| matter-server   | —        |                                              |

## Config Notes

### Home Assistant

External access via envoy-external. Uses Multus for a secondary network interface — this gives it direct LAN presence for device discovery (mDNS, SSDP) that wouldn't work through the Cilium CNI alone. VolSync backs up the config PVC.

### ESPHome

Same Multus setup as Home Assistant — mDNS for ESP device discovery on the LAN.

### Z-Wave

Requires USB device passthrough to the pod for the Z-Wave controller stick. Node affinity ensures it schedules on the node with the USB device attached.

### Mosquitto

MQTT message broker. Home Assistant and ESPHome both depend on it for IoT device communication. No external access — cluster-internal only.
