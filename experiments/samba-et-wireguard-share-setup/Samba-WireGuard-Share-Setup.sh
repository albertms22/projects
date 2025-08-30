#!/bin/bash
# Samba + WireGuard Setup for Ubuntu Systems
set -e  # Exit immediately on any error

echo "📦 Updating the system's package catalog…"
if ! sudo apt update -y; then
    echo "❌ Failed to update package list. Exiting."
    exit 1
fi

echo "⬆️ Upgrading installed software to the latest versions…"
if ! sudo apt upgrade -y; then
    echo "❌ Failed to upgrade packages. Exiting."
    exit 1
fi

echo "📦 Installing Samba and WireGuard..."
if ! sudo apt install -y samba wireguard; then
    echo "❌ Failed to install Samba and WireGuard. Exiting."
    exit 1
fi

echo "✅ All tasks completed successfully!"

# Create Samba-only user
USERNAME="smbuser"

echo "👤 Setting up Samba-only user: $USERNAME"

read -s -p "🔑 Enter password for $USERNAME: " PASSWORD
echo
read -s -p "🔑 Confirm password for $USERNAME: " PASSWORD_CONFIRM
echo

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo "❌ Passwords do not match. Exiting."
    exit 1
fi

if id "$USERNAME" &>/dev/null; then
    echo "ℹ️ User $USERNAME already exists, skipping system user creation."
else
    echo "👤 Creating system user $USERNAME (no home, no login)..."
    sudo adduser --no-create-home --shell /usr/sbin/nologin "$USERNAME"
fi

# Add to Samba
( echo "$PASSWORD"; echo "$PASSWORD" ) | sudo smbpasswd -a "$USERNAME"
sudo smbpasswd -e "$USERNAME"

echo "✅ Samba user $USERNAME is ready!"

# Create Samba shared directories
echo "📂 Creating Samba share directories..."

# Main directories
sudo mkdir -p /srv/samba/videos
sudo mkdir -p /srv/samba/shared

# If you want to serve videos from an external HDD, mounted at /mnt/external/videos(commented)
#if [ -d /mnt/external/videos ]; then
   # echo "🔗 Binding external HDD videos into /srv/samba/videos..."
    #sudo mount --bind /mnt/external/videos /srv/samba/videos
#fi

# Adjust ownership and permissions for videos directory
# Videos: owned by root, group = smbuser
# Set sticky bit to prevent deletion even if someone has write permission
sudo chown -R root:smbuser /srv/samba/videos
sudo chmod -R 2775 /srv/samba/videos  # Setgid bit preserves group ownership
find /srv/samba/videos -type f -exec chmod 664 {} \;  # Files: read/write for group, read for others
find /srv/samba/videos -type d -exec chmod 2775 {} \;  # Directories: sticky bit + rwx for group, rx for others

# Adjust ownership and permissions for shared directory
# Shared: owned by root, group = smbuser
sudo chown -R root:smbuser /srv/samba/shared
sudo chmod -R 2775 /srv/samba/shared  # Setgid bit preserves group ownership
find /srv/samba/shared -type f -exec chmod 664 {} \;  # Files: read/write for group, read for others
find /srv/samba/shared -type d -exec chmod 2775 {} \;  # Directories: sticky bit + rwx for group, rx for others

# Add the sticky bit to prevent file deletion (even by owners)
sudo chmod +t /srv/samba/videos
sudo chmod +t /srv/samba/shared

echo "✅ Samba directories prepared with enhanced permissions:"
echo "   - /srv/samba/videos (read-only for others, no deletion allowed)"
echo "   - /srv/samba/shared (read/write for smbuser group, no deletion allowed)"

# Configure Samba
echo "📝 Configuring Samba..."

# Backup original smb.conf
if [ ! -f /etc/samba/smb.conf.bak ]; then
    sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
fi

# Append our share configurations
sudo tee -a /etc/samba/smb.conf > /dev/null << EOF

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

[videos]
   path = /srv/samba/videos
   comment = Videos Library (Read-Only + Add)
   browsable = yes
   read only = no
   valid users = @smbuser
   force create mode = 0664
   force directory mode = 2775
   force group = smbuser

[shared]
   path = /srv/samba/shared
   comment = Shared Files (Read-Write + Add)
   browsable = yes
   read only = no
   valid users = @smbuser
   force create mode = 0664
   force directory mode = 2775
   force group = smbuser
EOF

# Restart Samba to apply changes
echo "🔄 Restarting Samba service..."
sudo systemctl restart smbd nmbd
sudo systemctl enable smbd nmbd

echo "✅ Samba configuration complete!"

# WireGuard Setup
echo "🛡️ Setting up WireGuard..."

# Create directory for WireGuard keys and configs
sudo mkdir -p /etc/wireguard/configs
cd /etc/wireguard

# Generate keys
echo "🔑 Generating WireGuard keys..."
SERVER_PRIVATE_KEY=$(wg genkey)
SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

# Save keys to files
echo "$SERVER_PRIVATE_KEY" | sudo tee server.key > /dev/null
echo "$SERVER_PUBLIC_KEY" | sudo tee server.pub > /dev/null
echo "$CLIENT_PRIVATE_KEY" | sudo tee client.key > /dev/null
echo "$CLIENT_PUBLIC_KEY" | sudo tee client.pub > /dev/null

# Set proper permissions for keys
sudo chmod 600 server.key client.key
sudo chmod 644 server.pub client.pub

# Create WireGuard configuration
echo "📝 Creating WireGuard configuration..."

# Get server's public IP (you may want to customize this)
SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
SERVER_PORT=51820
CLIENT_IP="10.0.0.2/24"
SERVER_CIDR="10.0.0.1/24"

# Create server configuration
sudo tee /etc/wireguard/configs/wg0.conf.example > /dev/null << EOF
[Interface]
Address = $SERVER_CIDR
ListenPort = $SERVER_PORT
PrivateKey = $SERVER_PRIVATE_KEY
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_IP
EOF

# Create client configuration
sudo tee /etc/wireguard/configs/client.conf > /dev/null << EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP
DNS = 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

 Set proper permissions for the config file
sudo chmod 600 /etc/wireguard/wg0.conf

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
sudo sysctl -p

# Basic firewall setup
sudo ufw allow 51820/udp
sudo ufw allow ssh
sudo ufw enable

# Start services
sudo systemctl restart smbd nmbd
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

echo "✅ WireGuard setup complete!"
echo "📋 Summary:"
echo "   - User: $USERNAME"
echo "   - Videos share: /srv/samba/videos (view/copy/add but no delete)"
echo "   - Shared folder: /srv/samba/shared (view/copy/add but no delete)"
echo "   - Both shares require authentication with user: $USERNAME"
echo "   - WireGuard server configured: wg0"
echo "   - Server public key: $SERVER_PUBLIC_KEY"
echo "   - Client configuration: /etc/wireguard/configs/client.conf"
echo ""
echo "⚠️   Remember to:"
echo "   - Review /etc/wireguard/wg0.conf for your network settings"
echo "   - Adjust the Endpoint in client.conf to your server's public IP"
echo "   - Review firewall rules: sudo ufw status verbose"
echo "   - Test VPN connectivity before relying on it"
