#!/bin/bash
# Ubuntu Workstation Setup Script
# Author: Albert Mitini
# Description: Sets up my development environment with all tools I need

set -e

echo "Starting full Workstation setup..."
sleep 2

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Helper functions ---
check_command() {
    command -v "$1" >/dev/null 2>&1
}

print_status() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# --- Update system ---
print_status "Updating package list..."
sudo apt update && sudo apt upgrade -y

# --- Basic CLI tools ---
print_status "Installing basic CLI tools..."
for pkg in htop jq curl wget git vim tmux unzip gnome-tweaks; do
    if ! check_command $pkg; then
        echo "Installing $pkg..."
        sudo apt install -y $pkg
    else
        echo "$pkg already installed, skipping..."
    fi
done

# --- Configure Git ---
if check_command git; then
    print_status "Configuring Git..."
    git config --global user.name "Your Name"
    git config --global user.email "your.email@example.com"
    git config --global init.defaultBranch main
else
    print_error "Git not installed, skipping configuration..."
fi

# --- GUI Applications ---
print_status "Installing GUI applications..."

# --- Install Samba and WireGuard ---
echo "📦 Installing Samba and WireGuard..."
if ! sudo apt install -y samba wireguard; then
    echo "❌ Failed to install Samba and WireGuard. Exiting."
    exit 1
fi

# Install other GUI apps (Spotify, Discord, etc.)
apps_to_install=()

# Check which apps need to be installed
if ! check_command spotify; then apps_to_install+=(spotify-client); fi
if ! check_command telegram-desktop; then apps_to_install+=(telegram-desktop); fi
if ! check_command discord; then apps_to_install+=(discord); fi
if ! check_command slack; then apps_to_install+=(slack); fi
if ! check_command kdeconnect-cli; then apps_to_install+=(kdeconnect); fi

# Install all needed apps at once
if [ ${#apps_to_install[@]} -ne 0 ]; then
    print_status "Installing: ${apps_to_install[*]}"
    sudo apt install -y "${apps_to_install[@]}"
else
    print_status "All GUI applications already installed"
fi

# --- Development Tools ---
print_status "Installing development tools..."

# --- Python & pip ---
if ! check_command python3; then
    echo "Installing Python3..."
    sudo apt install -y python3 python3-pip
else
    echo "Python3 already installed, skipping..."
fi

# --- Node.js & npm ---
if ! check_command node; then
    echo "Installing Node.js and npm..."
    sudo apt install -y nodejs npm
else
    echo "Node.js already installed, skipping..."
fi

# --- Terraform ---
if ! check_command terraform; then
    echo "Installing Terraform..."
    wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
    unzip terraform_1.6.0_linux_amd64.zip
    sudo mv terraform /usr/local/bin/
    rm terraform_1.6.0_linux_amd64.zip
else
    echo "Terraform already installed, skipping..."
fi

# --- Ansible ---
if ! check_command ansible; then
    echo "Installing Ansible..."
    sudo apt install -y ansible
else
    echo "Ansible already installed, skipping..."
fi

# --- Docker & Docker Compose ---
if ! check_command docker; then
    echo "Installing Docker..."
    sudo apt install -y docker.io docker-compose
    sudo systemctl enable docker
else
    echo "Docker already installed, skipping..."
fi

# --- AWS CLI ---
if ! check_command aws; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws
else
    echo "AWS CLI already installed, skipping..."
fi

# --- Azure CLI ---
if ! check_command az; then
    echo "Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
else
    echo "Azure CLI already installed, skipping..."
fi

# --- Google Cloud SDK ---
if ! check_command gcloud; then
    echo "Installing Google Cloud SDK..."
    sudo apt install -y apt-transport-https ca-certificates gnupg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo tee /usr/share/keyrings/cloud.google.gpg
    sudo apt update
    sudo apt install -y google-cloud-sdk
else
    echo "Google Cloud SDK already installed, skipping..."
fi

# --- VS Code ---
if ! check_command code; then
    echo "Installing VS Code..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
    sudo sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    sudo apt update
    sudo apt install -y code
    rm packages.microsoft.gpg
else
    echo "VS Code already installed, skipping..."
fi

# --- GNOME Tweaks & Dock customization ---
print_status "Setting up GNOME Tweaks and transparent dock..."
sudo apt install -y gnome-shell-extensions
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false
gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.0

# --- Optional AI helpers (commented) ---
# echo "Setting up Claude CLI (optional, requires API keys)..."
# npm install -g @anthropic-ai/cli

# --- Create projects folder ---
mkdir -p ~/projects

print_success "Workstation setup complete!"
echo "You may want to reboot for all changes to take effect."
