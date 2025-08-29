# Secure File Sharing with Samba over WireGuard (Ubuntu Server + Windows Clients)

A clean, secure, and reproducible setup to host a private Samba (SMB) share on an **Ubuntu** server and let **Windows** clients access it through a **WireGuard VPN** tunnel — even when everyone is on different Wi‑Fi networks.

> Target audience: Technical beginners (e.g., early‑career cloud engineers) who want a project they can run at home/VPS **and** showcase on GitHub.

---

## Table of Contents
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Repository Layout](#repository-layout)
- [Network Plan](#network-plan)
- [Step 1 — Ubuntu Server: System Prep](#step-1--ubuntu-server-system-prep)
- [Step 2 — Install & Configure WireGuard (VPN Server)](#step-2--install--configure-wireguard-vpn-server)
- [Step 3 — Install & Configure Samba (SMB Server)](#step-3--install--configure-samba-smb-server)
- [Step 4 — Windows Client: WireGuard + SMB Access](#step-4--windows-client-wireguard--smb-access)
- [Firewall & Security Considerations](#firewall--security-considerations)
- [Testing & Troubleshooting](#testing--troubleshooting)
- [Example Config Files](#example-config-files)
- [Future Improvements](#future-improvements)
- [Credits & License](#credits--license)

---

## Architecture

```mermaid
flowchart LR
  subgraph Internet
  end

  W1[Windows Client A<br/>WireGuard Client] -- UDP 51820 --> WG[(WireGuard Server<br/>Ubuntu)]
  W2[Windows Client B<br/>WireGuard Client] -- UDP 51820 --> WG

  WG -- wg0 (10.8.0.1/24) --> SMB{{Samba daemon<br/>(ports 445/TCP, 137-139/NetBIOS UNUSED externally)}}

  W1 <-- SMB over VPN --> SMB
  W2 <-- SMB over VPN --> SMB

  classDef node fill:#f6f8fa,stroke:#333,stroke-width:1px;
  class W1,W2,WG,SMB node;
```

**Key idea:** Samba only listens on the **VPN interface (`wg0`)**. Nothing SMB-related is exposed to the public internet.

---

## Prerequisites
- Ubuntu 22.04 LTS or newer (server or VM; root/sudo access)
- Publicly reachable UDP port **51820** on the server’s WAN IP (configure router/NAT or security group)
- A domain or public IP you can give to clients (domain optional but nice)
- At least one Windows 10/11 client (WireGuard desktop app)
- Git installed if you want to clone this repo

---

## Repository Layout

```text
.
├── README.md                 # This document
├── configs/
│   ├── samba/smb.conf        # Hardened sample Samba config
│   ├── wireguard/wg0.conf    # Sample server config
│   └── wireguard/client.conf # Sample Windows client config (template)
└── diagrams/
    └── architecture.mmd      # Mermaid source (optional if you export PNGs)
```

*(You can copy the examples from the [Example Config Files](#example-config-files) section directly to your repo.)*

---

## Network Plan
- **WireGuard subnet:** `10.8.0.0/24`
  - Server (Ubuntu, `wg0`): `10.8.0.1`
  - Example Windows client: `10.8.0.2`
- **Samba share path:** `/srv/samba/secure_share`
- **Samba user:** `smbuser` (separate password from system login for safety)
- **Firewall:**
  - Expose **only** UDP **51820** to the internet
  - Allow SMB **only** on `wg0` (no exposure on public interface)

---

## Step 1 — Ubuntu Server: System Prep
```bash
# Update system
sudo apt update && sudo apt -y upgrade

# Optional: set hostname
sudo hostnamectl set-hostname files-vpn

# Install basic tools
sudo apt -y install vim git ufw jq
```

Enable uncomplicated firewall (**UFW**) and lock things down early:
```bash
# Allow SSH from anywhere or restrict to your IP ranges
sudo ufw allow OpenSSH

# Allow WireGuard server port (UDP 51820)
sudo ufw allow 51820/udp

# Deny everything else by default
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Enable firewall
sudo ufw enable
sudo ufw status verbose
```

---

## Step 2 — Install & Configure WireGuard (VPN Server)

### 2.1 Install WireGuard
```bash
sudo apt -y install wireguard
```

### 2.2 Generate keys
```bash
umask 077
wg genkey | tee ~/wg-server-private.key | wg pubkey > ~/wg-server-public.key
cat ~/wg-server-private.key
cat ~/wg-server-public.key
```
> Keep the **private key** secret. You’ll need the **public key** for client configs.

### 2.3 Create `/etc/wireguard/wg0.conf`
Create the file and adjust values as needed (also see the [Example Config Files](#example-config-files)).
```bash
sudo mkdir -p /etc/wireguard
sudo nano /etc/wireguard/wg0.conf
```

**Minimal, secure server config** (no LAN NAT; Samba is on the VPN interface):
```ini
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>
# Tight firewall integration handled separately (see UFW section)

# === Add peers below ===
# [Peer]
# PublicKey = <CLIENT_PUBLIC_KEY>
# AllowedIPs = 10.8.0.2/32
```

> If you want clients to also reach your **LAN** behind the server, enable IP forwarding and add `PostUp`/`PostDown` NAT rules. For this project, we keep it simple: clients talk to **the server only** over VPN, and the share is bound to `wg0`.

### 2.4 Enable IP forwarding (safe default)
Even if we’re not NATing to LAN, enabling forwarding is harmless and future‑proof:
```bash
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-wireguard-forwarding.conf
sudo sysctl --system
```

### 2.5 Start WireGuard
```bash
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
sudo systemctl status wg-quick@wg0 --no-pager
```

### 2.6 Add your first client (peer)
On the **client machine** (or temporarily on the server), generate a keypair:
```bash
wg genkey | tee ~/wg-client1-private.key | wg pubkey > ~/wg-client1-public.key
```
Add the client’s **public key** to the server configuration under a new `[Peer]` block, assign the client `10.8.0.2/32`, then restart WireGuard:
```bash
sudo nano /etc/wireguard/wg0.conf
sudo systemctl restart wg-quick@wg0
```

---

## Step 3 — Install & Configure Samba (SMB Server)

### 3.1 Install Samba
```bash
sudo apt -y install samba
```

### 3.2 Create share directory and permissions
```bash
sudo mkdir -p /srv/samba/secure_share
sudo groupadd -f sambashare
sudo useradd -M -s /usr/sbin/nologin -G sambashare smbuser
sudo chown -R root:sambashare /srv/samba/secure_share
sudo chmod -R 2770 /srv/samba/secure_share
```
> The `2` in `2770` sets the **setgid** bit so new files inherit the `sambashare` group.

### 3.3 Set Samba password for `smbuser`
```bash
sudo smbpasswd -a smbuser
```

### 3.4 Harden and bind Samba to `wg0`
Edit `/etc/samba/smb.conf`:
```bash
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
sudo nano /etc/samba/smb.conf
```
Recommended minimal config is in [Example Config Files](#example-config-files). Key points:
- Bind only to **loopback** and **wg0**
- Disable SMB1; require SMB2+; enforce modern crypto
- Share requires authentication; no guest access

Restart and validate:
```bash
sudo testparm
sudo systemctl restart smbd nmbd
sudo systemctl enable smbd nmbd
sudo systemctl status smbd --no-pager
```

### 3.5 UFW rules to allow SMB **only** on wg0
```bash
# Allow Samba strictly over the VPN interface
sudo ufw allow in on wg0 to any port 445 proto tcp
# (Optional) NetBIOS over TCP/UDP if needed by legacy tools; usually not required
sudo ufw allow in on wg0 to any port 139 proto tcp
sudo ufw allow in on wg0 to any port 137 proto udp
sudo ufw allow in on wg0 to any port 138 proto udp

# Block SMB on all other interfaces (default deny already does this)
sudo ufw status numbered
```

---

## Step 4 — Windows Client: WireGuard + SMB Access

### 4.1 Install WireGuard client
- Download **WireGuard for Windows** from the official site.
- Import the **client config** (see template below) via *Add Tunnel > Add empty tunnel* or *Import from file*.

### 4.2 Client config fields to set
- `PrivateKey`: client’s private key
- `Address`: `10.8.0.2/32` (or your assigned IP)
- `DNS`: optional; set to server or a public resolver
- `AllowedIPs`: `10.8.0.1/32` to talk only to the server, or `10.8.0.0/24` for whole VPN subnet
- `Endpoint`: `your.server.ip.or.domain:51820`

### 4.3 Connect and map the share
1. Turn on the WireGuard tunnel.
2. In **File Explorer**, type: `\\10.8.0.1\secure_share`
3. Authenticate with `smbuser` and the password you set with `smbpasswd`.
4. To mount as a drive letter, use **Map Network Drive** or run PowerShell:
```powershell
New-PSDrive -Name S -PSProvider FileSystem -Root \\10.8.0.1\secure_share -Persist -Credential (Get-Credential)
```

---

## Firewall & Security Considerations
- **Do not expose SMB** (445/TCP, 139/TCP, 137-138/UDP) to the internet. Bind Samba to `wg0` and `lo` only.
- **Expose only UDP 51820** for WireGuard on the WAN.
- **Strong keys**: WireGuard keys are short but modern and resistant; keep private keys secret.
- **Least privilege**: Use a dedicated `smbuser` without a login shell.
- **SMB hardening**: Disable SMB1; require SMB2+; modern ciphers; per-share access control.
- **Backups**: Treat `/srv/samba/secure_share` as important data; snapshot or back it up.
- **Patching**: Keep Ubuntu, Samba, and WireGuard packages updated.
- **Logging**: Monitor `/var/log/samba/` and `journalctl -u wg-quick@wg0 -u smbd`.
- **Optional rate-limiting**: Consider `ufw limit` for SSH and a tool like `fail2ban` for SSH.

---

## Testing & Troubleshooting
**On the server:**
```bash
# Is wg0 up and has the right IP?
ip addr show wg0
wg show

# Is Samba listening only on wg0 and lo?
sudo ss -tulpen | egrep 'smbd|:445|:139'

# Validate Samba config
sudo testparm -s
```

**From a Linux client (optional):**
```bash
# List shares
smbclient -L 10.8.0.1 -U smbuser
# Connect and test
smbclient //10.8.0.1/secure_share -U smbuser -c 'ls'
```

**Windows client tips:**
- Ensure WireGuard is **Connected** and shows handshake.
- Use `\\10.8.0.1\secure_share` (double backslashes). If name resolution fails, use the IP.
- Clear Windows cached credentials via **Credential Manager** if you changed passwords.

**Firewall sanity checks:**
- From the internet, `nmap` against your server should show UDP 51820 open and **not** show 445.
- From a connected client, `telnet 10.8.0.1 445` should connect.

---

## Example Config Files

> Copy these into your repo under `configs/` and adjust values in angle brackets.

### `configs/samba/smb.conf`
```ini
[global]
   server role = standalone server
   workgroup = WORKGROUP
   security = user
   map to guest = never

   # Bind only to loopback and WireGuard interface
   interfaces = 127.0.0.1/8 wg0
   bind interfaces only = yes

   # Harden SMB protocols – disable SMB1
   client min protocol = SMB2
   server min protocol = SMB2
   smb encrypt = required

   # Logging
   log file = /var/log/samba/%m.log
   max log size = 5000
   logging = file

   # Performance & sane defaults
   load printers = no
   printcap name = /dev/null
   disable spoolss = yes

[secure_share]
   path = /srv/samba/secure_share
   browsable = yes
   writable = yes
   read only = no
   create mask = 0660
   directory mask = 2770
   valid users = @sambashare
```

### `configs/wireguard/wg0.conf` (Server)
```ini
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>

# Example peer
[Peer]
PublicKey = <CLIENT1_PUBLIC_KEY>
AllowedIPs = 10.8.0.2/32
```

### `configs/wireguard/client.conf` (Windows Client Template)
```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.8.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
AllowedIPs = 10.8.0.1/32
Endpoint = <SERVER_PUBLIC_IP_OR_DNS>:51820
PersistentKeepalive = 25
```
> Change `AllowedIPs` to `10.8.0.0/24` if you plan to talk to other peers on the VPN later.

---

## Future Improvements
- **Nextcloud on the same server** (behind the VPN or reverse proxy) for web/mobile sync; leave Samba for Windows power‑users.
- **Monitoring & alerting**: node_exporter + Prometheus + Grafana; or simpler, `netdata`.
- **Backups & snapshots**: restic/Borg to S3/B2; optional ZFS/btrfs snapshots.
- **Automate with Ansible**: roles for WireGuard, Samba, UFW; generate client configs/QRs automatically.
- **User management**: script new user creation (`useradd` + `smbpasswd` + client config generation).
- **MFA for VPN access** (gateway approach): place WireGuard behind an SSO-capable bastion or use a jump host that enforces MFA prior to issuing client configs.
- **Central auth**: integrate Samba with your AD/LDAP if you grow beyond a single user.

---

## Credits & License
- Built for learning and practical home/side‑project use.
- License: MIT (or choose your favorite permissive license).

---

## Quick Start (TL;DR)
1. Set up WireGuard server (`wg0`) on Ubuntu, expose **UDP 51820** only.
2. Add a peer for each Windows client.
3. Install Samba, create `smbuser`, bind to `wg0`, share `/srv/samba/secure_share`.
4. On Windows, connect WireGuard, then browse to `\\10.8.0.1\secure_share`.
5. Verify firewall denies SMB from the internet.

You now have a tidy, private file server that works across any network — the old‑school reliability of SMB with the modern safety of WireGuard.

