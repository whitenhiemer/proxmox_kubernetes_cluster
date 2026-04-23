# GL-iNet Mango WireGuard Setup

Connect a GL-iNet GL-MT300N-V2 (Mango) travel router to the homelab WireGuard
VPN. When connected, all devices on the Mango's WiFi get full LAN access to
the homelab (192.168.86.0/24) as if they were on-site.

## Use Case

Plug the Mango into a hotel/Airbnb ethernet or connect it to guest WiFi as a
repeater, then connect your devices to the Mango's SSID. All traffic routes
through the WireGuard tunnel back to the homelab -- access Plex, Jellyfin,
Home Assistant, NAS shares, and all `*.woodhead.tech` services without
individual device VPN configs.

## Prerequisites

- WireGuard LXC deployed and running (`make wireguard`)
- UDP port 51820 forwarded on Google Nest -> 192.168.86.39
- GL-iNet Mango firmware 3.x or 4.x (WireGuard support built-in)
- Mango connected to a network with internet access

## Step 1: Add the Mango as a WireGuard Peer

Edit `ansible/playbooks/setup-wireguard.yml` and add a new entry to the
`wg_client_list`:

```yaml
wg_client_list:
  - name: brandon-laptop
    ip: "10.10.0.2"
  - name: brandon-phone
    ip: "10.10.0.3"
  - name: mango-travel       # <-- add this
    ip: "10.10.0.10"
```

Redeploy to generate the new peer config:

```bash
make wireguard
```

This regenerates `wg0.conf` with the new peer, creates
`ansible/files/wireguard/clients/mango-travel.conf`, and restarts the tunnel.

## Step 2: Retrieve the Client Config

After `make wireguard` completes, the config is fetched locally:

```bash
cat ansible/files/wireguard/clients/mango-travel.conf
```

The file looks like:

```ini
[Interface]
Address = 10.10.0.10/24
PrivateKey = <client-private-key>
DNS = 192.168.86.1

[Peer]
PublicKey = <server-public-key>
PresharedKey = <preshared-key>
Endpoint = woodhead.tech:51820
AllowedIPs = 192.168.86.0/24, 10.10.0.0/24
PersistentKeepalive = 25
```

You'll need each of these values for the Mango admin panel.

## Step 3: Configure the Mango

### Firmware 4.x (GL-iNet 4.x Admin Panel)

1. Connect to the Mango's WiFi (default SSID: `GL-MT300N-V2-xxx`)
2. Open `http://192.168.8.1` in a browser
3. Navigate to **VPN > WireGuard Client**
4. Click **Set Up WireGuard Manually** > **Configuration**
5. Paste the entire contents of `mango-travel.conf` into the text box
6. Click **Next**, then give the profile a name (e.g., "Homelab")
7. Click **Apply**
8. Toggle the connection **ON**

### Firmware 3.x (Older Admin Panel)

1. Connect to the Mango's WiFi
2. Open `http://192.168.8.1`
3. Navigate to **VPN > WireGuard Client**
4. Click **Add a New Group** and name it "Homelab"
5. Click **Add a New Config** and enter:
   - **Server Address**: `woodhead.tech:51820`
   - **Private Key**: `<client-private-key>` from the config
   - **Local IP Address**: `10.10.0.10/24`
   - **Peer Public Key**: `<server-public-key>` from the config
   - **Preshared Key**: `<preshared-key>` from the config
   - **Allowed IPs**: `192.168.86.0/24, 10.10.0.0/24`
   - **Persistent Keepalive**: `25`
   - **DNS**: `192.168.86.1`
6. Click **Add** then **Connect**

### Alternative: Import Config File

Both firmware versions support importing a `.conf` file directly:

1. VPN > WireGuard Client > **Add a New Configuration**
2. Choose **Upload** or **Import**
3. Select the `mango-travel.conf` file
4. Click **Apply** and toggle ON

## Step 4: Verify

From a device connected to the Mango's WiFi:

```bash
# Should reach the WireGuard server
ping 10.10.0.1

# Should reach the homelab LAN
ping 192.168.86.20

# Should resolve and load via Traefik
curl -I https://recipes.woodhead.tech
```

Check the tunnel status from the server side:

```bash
ssh root@192.168.86.39 "wg show"
```

The `mango-travel` peer should show a recent handshake and non-zero transfer bytes.

## VPN Policies (Optional)

The Mango supports VPN routing policies to control which traffic goes through
the tunnel:

- **All traffic through VPN**: VPN > Global Options > VPN Policy > "Route All
  Traffic" -- sends everything (including internet browsing) through the homelab.
  This adds latency but provides full privacy on untrusted networks.

- **Only homelab traffic through VPN** (split tunnel, default): With `AllowedIPs`
  set to `192.168.86.0/24, 10.10.0.0/24`, only traffic destined for the homelab
  routes through the tunnel. Internet traffic goes directly out the Mango's WAN.
  This is the default configuration from `make wireguard`.

To switch to full tunnel, edit the AllowedIPs in the Mango admin panel:
- Change `AllowedIPs` to `0.0.0.0/0`

Or update the Ansible config before deploying:
```yaml
# In setup-wireguard.yml, change:
wg_allowed_ips: "0.0.0.0/0"
```

## Troubleshooting

### Mango shows "Connected" but can't reach homelab

1. Check the server-side peer config has the Mango's public key:
   ```bash
   ssh root@192.168.86.39 "wg show wg0"
   ```
   The Mango peer should be listed. If not, `make wireguard` didn't run
   cleanly -- check the Ansible output.

2. Verify port forwarding: from an external network, test UDP connectivity:
   ```bash
   # From a device NOT on the homelab network
   nc -u -z woodhead.tech 51820
   ```

3. Check the Mango's WireGuard log: Admin Panel > VPN > WireGuard Client >
   click the log/status icon.

### Handshake timeout

- The Mango's upstream network may block UDP 51820. Try a different port by
  changing `wg_port` in the Ansible config and updating the Google Nest port
  forward.
- Some hotel/corporate networks block all non-standard UDP. WireGuard cannot
  work over TCP -- consider using a fallback like Cloudflare Tunnel in those
  environments.

### DNS resolution fails inside tunnel

- The default DNS (`192.168.86.1`, Google Nest) is only reachable through the
  tunnel. If the tunnel is up but DNS fails, try setting DNS to `1.1.1.1` or
  `8.8.8.8` in the Mango's WireGuard config as a fallback.
- `*.woodhead.tech` resolves via public Cloudflare DNS, so it works regardless
  of which DNS server is configured.

### Mango can't establish tunnel on hotel WiFi

- Some hotels require a captive portal login before internet access works.
  Connect to the hotel WiFi via the Mango's **Repeater** mode first, complete
  the captive portal, then enable the WireGuard tunnel.
- Admin Panel > Internet > Repeater > scan and connect to hotel WiFi.
