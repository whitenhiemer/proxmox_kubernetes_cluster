---
sidebar_position: 11
title: Zigbee2MQTT
---

# Zigbee2MQTT

LXC 214 | `192.168.86.36` | Port 8080 (Web UI), 1883 (MQTT) | on zotac

Zigbee USB dongle bridge that translates Zigbee protocol messages to MQTT topics. Enables Zigbee sensors and devices (temperature, motion, contact sensors, smart plugs) to integrate with Home Assistant via a shared Mosquitto broker.

## Architecture

- **Zigbee2MQTT**: Reads from the Zigbee USB coordinator, publishes device state to Mosquitto
- **Mosquitto**: MQTT broker on port 1883, subscribed to by Home Assistant
- **USB passthrough**: Zigbee coordinator (e.g., ConBee II, Sonoff Zigbee 3.0) passed through from zotac (`/dev/ttyUSB0` or `/dev/ttyACM0`)
- LXC runs on **zotac** (192.168.86.147) due to USB dongle being physically attached there

```
Zigbee Device (sensor/switch)
    |  Zigbee radio (2.4 GHz mesh)
    v
USB Coordinator (on zotac)
    |  /dev/ttyUSB0 -> LXC 214
    v
Zigbee2MQTT (LXC 214, port 8080)
    |  MQTT publish: zigbee2mqtt/<device_name>
    v
Mosquitto Broker (LXC 214, port 1883)
    |
    v
Home Assistant (192.168.86.41)
```

## Pairing a New Device

1. Open the Zigbee2MQTT web UI at `http://192.168.86.36:8080`
2. Click **Permit join** (or per-device join) to open a pairing window
3. Trigger pairing mode on your device (usually hold the button 5-10 seconds until LED flashes)
4. Device appears in the devices list once paired
5. In Home Assistant, the new device will appear automatically via the MQTT integration

## Deploy

```bash
# Provision the LXC
make apply-lxc

# Deploy Zigbee2MQTT + Mosquitto
make zigbee2mqtt
```

The USB device path is configured in the Ansible playbook. Update `ansible/playbooks/setup-zigbee2mqtt.yml` if the coordinator appears on a different path.

## Verify

```bash
# Check services
ssh root@192.168.86.36 'systemctl status zigbee2mqtt mosquitto'

# Check MQTT messages from a paired device
ssh root@192.168.86.36 'mosquitto_sub -t "zigbee2mqtt/#" -v'

# Logs
ssh root@192.168.86.36 'journalctl -u zigbee2mqtt -f'
```

## Troubleshooting

- **Coordinator not found**: Verify USB passthrough in Proxmox — LXC must have the USB device mapped. Check `ls /dev/ttyUSB*` or `/dev/ttyACM*` inside the LXC.
- **Devices not appearing in HA**: Confirm the MQTT integration in Home Assistant points to `192.168.86.36:1883`; check Mosquitto is running.
- **Can't pair device**: Ensure permit join is enabled in the web UI; some devices require a factory reset before re-pairing.
- **Zigbee2MQTT crashes on start**: Check the coordinator serial path in `/opt/zigbee2mqtt/data/configuration.yaml` matches the actual device path.
