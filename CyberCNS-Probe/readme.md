# CyberCNS Deployment Script for Blackbird Probe VMs

## Overview
This script automates the setup and deployment process for CyberCNS probes on Blackbird probe virtual machines. It configures the server's hostname, installs essential tools, sets up DNS and email configurations, enables unattended upgrades, and installs necessary security utilities.

### Author
- **Adam Tee**

### Version
- **Alpha 30.10.2024**

## Features
- **Hostname Configuration**: Prompts for a new hostname and updates it across the system.
- **VM Tools Installation**: Installs Open VM Tools for virtualisation support.
- **DNS Setup**: Configures DNS servers to use Cloudflare and Google DNS.
- **Email Setup**: Installs and configures `mailutils` and `postfix` for email sending via SMTP relay.
- **Unattended Upgrades**: Configures automatic updates and sets email notifications for upgrade reports.
- **Nmap and OpenSCAP**: Installs network scanning and security compliance tools.
- **CyberCNS Probe Installation**: Downloads and installs the CyberCNS Probe with specified company and tenant IDs.

## Requirements
- **Operating System**: Ubuntu Server
- **Root Privileges**: The script requires `sudo` access to modify system files and install packages.
- **Internet Access**: Internet connectivity is required to download necessary packages and the CyberCNS probe.

## Usage
1. **Download the Script**
   - Use the following command to download, set execute permissions, and run the script:
     ```bash
     curl -L -o DeploymentScript.sh "https://raw.githubusercontent.com/Red5Blackbird/Blackbird-Scripts/refs/heads/main/CyberCNS-Probe/DeploymentScript.sh" && chmod +x DeploymentScript.sh && ./DeploymentScript.sh
     ```
2. **Follow Prompts**
   - Enter required information when prompted:
     - New hostname
     - SMTP relay details
     - Company ID and Tenant ID for CyberCNS Probe

## Script Workflow

1. **Hostname Setup**
   - Prompts for and sets a new hostname, updating `/etc/hostname` and `/etc/hosts` accordingly.

2. **Install VM Tools**
   - Installs Open VM Tools to optimise performance on virtualised environments.

3. **Configure DNS Servers**
   - Sets up DNS with Cloudflare and Google DNS servers by updating `/etc/systemd/resolved.conf`.

4. **Email Configuration**
   - Installs `mailutils` and `postfix`, then configures `postfix` to send emails via a specified SMTP relay, using `hostname@domain` as the sender address.
   - Sends a test email to confirm delivery, with options to reconfigure SMTP settings if the test fails.

5. **Enable Unattended Upgrades**
   - Configures automatic updates for package lists and upgrades.
   - Sends notifications to a specified email for upgrade events.

6. **Install Security Tools**
   - Installs `nmap` and `openscap-scanner` for network scanning and security compliance.

7. **Install CyberCNS Probe**
   - Prompts for Company ID and Tenant ID, then downloads and installs the CyberCNS probe.

## Customisation
- **Email Domain**: When configuring Postfix, the script prompts for an email domain, allowing you to set the email sender as `hostname@domain`.
- **Unattended Upgrades Notification**: Set the notification email for unattended upgrades in the script under the `Unattended-Upgrade::Mail` setting.

## Troubleshooting
- **Email Delivery Issues**: If the test email fails, the script allows reconfiguration of SMTP relay settings.
- **Permission Errors**: Ensure the script is run as root or with `sudo`.
- **Internet Access**: Verify internet connectivity if package downloads or probe installation fail.

## License
This project is licensed under the MIT License.

## Disclaimer
This script is provided as-is without any guarantees. Ensure you review and understand the changes before applying it to production systems.
