# Samba & OpenVPN Setup Script
--------------------------------------------------------------------------------------------------

## 📖 Overview

Automated setup scripts and sample configs for Samba file sharing and OpenVPN server on Linux.

--------------------------------------------------------------------------------------------------

## ✨ Features

 - Automates installation and setup of Samba and OpenVPN

 - Includes example configuration files for customization

 - Easy to extend or modify for your environment

----------------------------------------------------------------------------------------------------

## 🚀 Requirements

Before running this script, ensure your system meets the following requirements:
  - Linux (tested on Ubuntu 20.04)

  - Root privileges

  - Basic networking knowledge
    
--------------------------------------------------------------------------------------------------

## 🛠️ Installation & Usage

 - git clone https://github.com/albertms22/samba-openvpn-setup.git
 - cd samba-openvpn-setup
 - chmod +x setup.sh
 - ./setup.sh

--------------------------------------------------------------------------------------------------

## ⚙️ Configuration

For those who prefer a manual setup over using the automated script, follow these steps:
1. Configure Samba

- sudo cp configs/smb.conf.example /etc/samba/smb.conf

Edit the file to match your desired shares and settings:

- sudo nano /etc/samba/smb.conf

2. Configure OpenVPN

- sudo cp configs/server.conf.example /etc/openvpn/server.conf

Edit the file to set your protocol, port, and network settings:

- sudo nano /etc/openvpn/server.conf

3. Restart the services to apply changes

- sudo systemctl restart smbd nmbd
- sudo systemctl restart openvpn@server

## 💻 Usage


