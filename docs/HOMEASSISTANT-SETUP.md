# Home Assistant OS Setup Guide

Step-by-step guide for deploying Home Assistant OS (HAOS) on Proxmox.

## Prerequisites

- Proxmox VE running with at least one node
- Internet access on the Proxmox node (Terraform downloads the HAOS image)
- Terraform configured per the main RUNBOOK

## How HAOS Differs from Other VMs

Unlike OPNsense and TrueNAS which boot from ISOs and go through an installer,
HAOS ships as a pre-built disk image. There's no install step -- Terraform
downloads the qcow2 image, imports it as the VM's boot disk, and HAOS boots
directly. All configuration happens through the web UI.

## 1. Create the Home Assistant VM

```bash
# Preview what will be created
cd terraform && terraform plan -target=proxmox_virtual_environment_vm.homeassistant

# Create the VM (downloads HAOS image + creates VM in one step)
make apply-homeassistant
```

This does two things:
1. Downloads the HAOS qcow2.xz image to Proxmox storage (decompresses automatically)
2. Creates the VM with the image imported as the boot disk

## 2. First Boot

1. Open Proxmox web UI -> VM 301 (homeassistant) -> Console
2. HAOS boots automatically (no installer, no user interaction needed)
3. Wait 2-3 minutes for initial setup to complete
4. The console will show: `homeassistant login:` and the web UI URL

## 3. Initial Configuration

Access the web UI at `http://10.0.0.31:8123` (or whatever IP DHCP assigned).

### 3.1 Onboarding Wizard

1. Create your admin account
2. Set your home location (for weather, sunrise/sunset automations)
3. Configure discovered devices
4. Done -- you're in the HA dashboard

### 3.2 Set Static IP

HAOS defaults to DHCP. Set a static IP so the address doesn't change:

1. **Settings** -> **System** -> **Network**
2. Click your network interface (usually `enp0s18`)
3. IPv4: Switch from DHCP to Static
   - IP: `10.0.0.31/24`
   - Gateway: `10.0.0.1`
   - DNS: `10.0.0.1`
4. Save

The web UI will reconnect at the new IP: `http://10.0.0.31:8123`

## 4. USB Passthrough (Zigbee/Z-Wave)

If you have a Zigbee or Z-Wave USB dongle (e.g., SONOFF Zigbee 3.0,
ConBee II, Aeotec Z-Stick), pass it through to the VM.

### 4.1 Identify the Dongle

On the Proxmox host:
```bash
# List USB devices
lsusb

# Example output:
# Bus 001 Device 003: ID 10c4:ea60 Silicon Labs CP210x UART Bridge
#                         ^^^^:^^^^
#                         vendor:product
```

### 4.2 Pass Through the USB Device

```bash
# Replace vendor:product with your dongle's IDs
qm set 301 -usb0 host=10c4:ea60

# Verify
qm config 301 | grep usb
```

### 4.3 Configure in Home Assistant

1. **Settings** -> **Devices & Services** -> **Add Integration**
2. Search for your protocol:
   - **Zigbee Home Automation (ZHA)** for Zigbee dongles
   - **Z-Wave JS** for Z-Wave dongles
3. Select the USB device (usually `/dev/ttyUSB0` or `/dev/ttyACM0`)
4. Start pairing devices

## 5. Recommended Addons

Install addons via **Settings** -> **Add-ons** -> **Add-on Store**:

| Addon | Purpose |
|-------|---------|
| **File Editor** | Edit configuration.yaml from the web UI |
| **Terminal & SSH** | SSH access to HAOS for debugging |
| **Mosquitto MQTT** | MQTT broker for IoT devices (Zigbee2MQTT, Tasmota) |
| **Zigbee2MQTT** | Alternative to ZHA with more device support |
| **Node-RED** | Visual flow-based automation editor |
| **ESPHome** | Program ESP32/ESP8266 devices for local control |
| **Samba Share** | Access HA config files from your network |

## 6. Backup to TrueNAS

After TrueNAS is configured, set up automatic backups:

### 6.1 Create NFS Share on TrueNAS

1. TrueNAS: Create dataset `pool/backups/homeassistant`
2. TrueNAS: Create NFS share -> `/mnt/pool/backups/homeassistant`
3. Authorized network: `10.0.0.0/24`

### 6.2 Configure HA Backup

Option A: **Built-in Backups** (simplest)
1. **Settings** -> **System** -> **Backups**
2. Create a backup manually or set a schedule
3. Download backups and store on TrueNAS via Samba share

Option B: **Auto-backup Addon**
1. Install the "Home Assistant Google Drive Backup" addon
2. Or use a network share addon to push backups to TrueNAS NFS

## 7. OPNsense DNS Override

Add a local DNS entry so `home.woodhead.tech` resolves internally:

1. OPNsense -> **Services** -> **Unbound DNS** -> **Overrides** -> **Host Overrides**
2. Add: `home` / `woodhead.tech` -> `10.0.0.31`

## 8. Enable Traefik Route (Optional)

To access Home Assistant via `https://home.woodhead.tech`:

1. Uncomment the route in `ansible/files/traefik/dynamic/homeassistant.yml`
2. Redeploy Traefik: `make traefik`

**Security note:** Exposing Home Assistant externally means anyone can reach
the login page. Consider:
- Strong password + 2FA (Settings -> Profile -> Multi-factor Authentication)
- Traefik IP whitelist middleware (only allow your public IP)
- Use HA's built-in Cloudflare integration or Nabu Casa instead

## 9. IoT Network Segmentation (Optional)

If running OPNsense with VLANs, put IoT devices on a separate VLAN:

1. OPNsense: Create VLAN 30 (10.0.30.0/24) for IoT devices
2. Firewall rules: Allow IoT VLAN -> HA (10.0.0.31:8123) only
3. Block IoT -> LAN (prevent smart devices from reaching your computers)
4. HA can still communicate with IoT devices because the firewall allows
   traffic FROM HA TO the IoT VLAN

This prevents compromised IoT devices from accessing your main network.

## Updating HAOS

HAOS handles its own updates:

1. **Settings** -> **System** -> **Updates**
2. Updates for HA Core, Supervisor, and OS appear here
3. Always create a backup before updating

To update the HAOS version in Terraform (for new VM deployments):
1. Check the latest release at https://github.com/home-assistant/operating-system/releases
2. Update `homeassistant_image_url` in your `terraform.tfvars`

## Verification Checklist

- [ ] VM 301 boots and shows HAOS login prompt on console
- [ ] Web UI accessible at `http://10.0.0.31:8123`
- [ ] Static IP configured (survives reboot)
- [ ] Admin account created via onboarding wizard
- [ ] USB dongle passed through and working (if applicable)
- [ ] MQTT broker running (if using Zigbee2MQTT/Tasmota)
- [ ] Backups configured

## Troubleshooting

### VM won't boot
```bash
# Check VM config on Proxmox host
qm config 301

# Verify BIOS is set to OVMF (UEFI)
# Verify machine type is q35
# Verify the disk was imported correctly
qm disk list 301
```

### Web UI not reachable
```bash
# Check if the VM has network
# Open Proxmox console -> HAOS CLI
ha network info

# Check the assigned IP
ip addr show
```

### USB dongle not detected
```bash
# Verify passthrough on Proxmox host
qm config 301 | grep usb

# Check inside HAOS (install Terminal addon first)
ls /dev/ttyUSB* /dev/ttyACM*

# If the device shows on the host but not in the VM,
# try unplugging and replugging the dongle
```

### HAOS stuck on boot
- Ensure UEFI/OVMF is set (not SeaBIOS)
- Ensure machine type is q35
- Try increasing memory to 4096 if 2048 isn't enough
- Check Proxmox task log for disk import errors
