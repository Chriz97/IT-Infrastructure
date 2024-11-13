
This repository, **IT-Infrastructure**, is a collection of scripts and configuration files tailored for managing and configuring Linux and Windows environments. These resources are valuable for system administrators working in IT infrastructure, covering essential aspects such as automatic updates, Docker installation, firewall configuration, GRUB adjustments for NVIDIA compatibility, and Active Directory management.

---

## Linux Scripts and Manuals

### Linux_Automatic_Update_DNF
**Description**: This script automates system updates on RHEL-based Linux distributions using `dnf-automatic`. It configures automatic downloads and installations, ensuring systems stay up-to-date with the latest security patches.

**Features**:
- Installs and configures `dnf-automatic`. (Also called dnf5-autmatic-plugin on Fedora)
- Enables and manages timers for scheduled updates.
- Configures email notifications for update summaries.

### Linux_Docker_Installation
**Description**: This manual provides step-by-step instructions to install Docker CE on RHEL-based distributions. It’s tailored for administrators who need Docker without Podman compatibility.

**Features**:
- Installs Docker CE and its dependencies.
- Configures Docker to start automatically on boot.
- Includes commands for managing containers, images, and network configurations.

### Linux_Essential_Commands
**Description**: A script and guide covering essential Linux commands for file management, process control, network diagnostics, and more.

**Features**:
- Covers basic commands for navigation, file management, and permissions.
- Includes process management and system resource monitoring commands.
- Useful for quick reference and foundational knowledge.

### Linux_Firewalld_Basic_Configuration
**Description**: This script provides a basic configuration for `firewalld`, including common commands to manage zones, open or close ports, and enable logging.

**Features**:
- Installs and configures `firewalld`.
- Demonstrates commands for setting up zones and managing services.
- Useful for administrators who need to secure their Linux systems with custom firewall rules.

### Linux_Grub_Configuration_Fedora_Nvidia
**Description**: A GRUB configuration manual for Fedora systems with NVIDIA graphics cards. This guide helps resolve compatibility issues with NVIDIA by blacklisting the Nouveau driver.

**Features**:
- Updates GRUB with NVIDIA-compatible settings.
- Blacklists Nouveau drivers and enables `nvidia-drm.modeset=1` for better graphics performance.
- Helps administrators with dual GPU or dedicated NVIDIA setups.

---

## Windows Scripts and Manuals

### Windows_Active_Directory_Script
**Description**: A PowerShell script for managing Active Directory users and groups. It’s tested on Windows Server 2025 and provides essential user and group management commands.

**Features**:
- Creates new users with specific attributes.
- Adds users to groups and resets passwords.
- Includes checks for group existence and automatic group creation if missing.
