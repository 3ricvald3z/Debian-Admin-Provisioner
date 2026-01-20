# Debian-Admin-Provisioner

A comprehensive post-installation and system hardening script for Debian 13 (Trixie). This project automates the transition from a fresh OS install to a fully configured, secure, and production-ready administrative workstation.

## 🚀 Overview
This script is designed for IT professionals and system administrators who need a consistent, repeatable environment setup. It handles everything from repository management and security hardening to the installation of advanced networking and virtualization tools.

## 🛠️ Key Features
- **Security Hardening:** Automatically configures `UFW` (Uncomplicated Firewall) and `Fail2Ban` to protect against unauthorized access.
- **Automated Provisioning:** Installs a full suite of admin tools including `Ansible`, `Nmap`, `Wireshark`, and `Git`.
- **Specialized Hardware Support:** Includes automated driver installation for **MediaTek-based high-gain wireless antennas**, enabling immediate network auditing and signal mapping capabilities.
- **Resilient Virtualization:** Sets up VirtualBox with automated kernel module compilation to ensure stability across kernel updates.
- **Optimized Shell Environment:** Customizes `.bashrc` with advanced aliases for system maintenance, logs monitoring, and networking tasks.

## 📋 Prerequisites
- A fresh installation of **Debian 13 (Trixie)**.
- Sudo privileges.

## ⚙️ Usage
1. **Clone the repository:**
   ```bash
   git clone https://github.com/3ricvald3z/Debian-Admin-Provisioner.git
   cd Debian-Admin-Provisioner
2. **Make the script executable:**
	```bash
	chmod +x debian13_GNOME_post_install.sh
	```
3. **Run the script:**
	```bash
	sudo ./debian13_GNOME_post_install.sh
	```
## ⚠️ Disclaimer

This script makes significant changes to system configurations and security settings. It is provided "as-is." Always review the source code before running it on a production system.
