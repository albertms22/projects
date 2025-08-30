# Samba & OpenVPN Auto-Setup Script

--------------------------------------------------------------------------------------------------

## 📖 Overview

This project provides a Bash script that automates the setup and configuration of:
  - Samba → for local file sharing
  - OpenVPN → for secure remote access
It is designed for Ubuntu/Debian-based systems and aims to simplify a process that usually requires many manual steps.

In addition to the script, the repository also includes ready-to-use configuration files. These are useful if you prefer to handle the installation and setup manually, without running the script.

--------------------------------------------------------------------------------------------------

## ⚠️ Disclaimer

**Use the quick installation script at your own risk**. It modifies critical network and system configurations. It is highly recommended to:

    1. **Read and understand the script ** (setup.sh) before running it.

    2. **Run it on a fresh system or a virtual machine** first to test its behavior.

   3.  **Have backups** of any important data on your system.

I am not responsible for any system instability, security breaches, or data loss resulting from the use of this script.

----------------------------------------------------------------------------------------------------

## 🚀 Pre-requisites

Before running this script, ensure your system meets the following requirements:

    **OS:** A Ubuntu or Debian-based Linux distribution (e.g., Ubuntu 20.04/22.04, Debian 11/12).

    **Permissions:** You must have sudo privileges to run the script.

   **Internet Connection:** Required to download and install packages.

    **Static IP (Recommended):** For reliable Samba sharing, your server should have a static IP address on your local network.
    
--------------------------------------------------------------------------------------------------

##🛠️ Installation & Usage

