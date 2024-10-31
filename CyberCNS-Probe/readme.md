# CyberCNS Deployment Script for Blackbird Probe VM

This script automates the deployment and configuration of a CyberCNS probe on a Blackbird Probe Virtual Machine. It includes system setup, DNS configuration, and unattended upgrades, along with the installation of necessary tools like Nmap, OpenSCAP, Open VM Tools, Mailutils, and Postfix.

## Features

- **Hostname Reconfiguration**: Prompt for a new hostname, update `/etc/hostname` and `/etc/hosts` accordingly.
- **DNS Setup**: Configures Cloudflare and Google DNS servers in `/etc/systemd/resolved.conf`.
- **Open VM Tools Installation**: Ensures the VM tools are installed for improved virtual machine performance.
- **Mail Configuration**: Sets up `mailutils` and `Postfix` for sending alerts via email, with options for SMTP configuration and test email.
- **Unattended Upgrades**: Enables and configures automatic updates with email alerts for package upgrades and security patches.
- **CyberCNS Probe Installation**: Downloads and installs the CyberCNS agent using a provided `Company ID` and `Tenant ID`.
- **User Password Update**: Allows updating the password for the `serveradmin` user securely.

## Requirements

- **Operating System**: Ubuntu (recommended)
- **Root/Sudo Privileges**: Required for system configuration changes
- **Internet Access**: Required for downloading packages and agent

## Usage
1. **Download the Script**
   - Use the following command to download, set execute permissions, and run the script:
     ```bash
     curl -L -o DeploymentScript.sh "https://raw.githubusercontent.com/Red5Blackbird/Blackbird-Scripts/refs/heads/main/CyberCNS-Probe/DeploymentScript.sh" && chmod +x DeploymentScript.sh && ./DeploymentScript.sh
     ```
2. **Follow Prompts**
   - Enter required information when prompted:
     - New hostname
     - SMTP details
     - Company ID and Tenant ID for CyberCNS Probe
