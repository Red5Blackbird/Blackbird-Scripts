#!/bin/bash

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

#-----------------------------
# CyberCNS Deployment Script
# For Blackbird Probe VM's
# Written by Adam Tee
# Version Alpha 30.10.2024
#-----------------------------

# ----------------------------
# Template Reconfiguration
# ----------------------------

# Prompt for new hostname
echo -e "${YELLOW}Enter the new hostname:${NC}"
read -p "> " new_hostname

# Validate input
if [[ -z "$new_hostname" ]]; then
    echo -e "${RED}Hostname cannot be empty. Exiting.${NC}"
    exit 1
fi

# Set the hostname temporarily and update configuration files
echo -e "${GREEN}Setting temporary hostname to $new_hostname...${NC}"
sudo hostnamectl set-hostname "$new_hostname"

echo -e "${GREEN}Updating /etc/hostname with $new_hostname...${NC}"
echo "$new_hostname" | sudo tee /etc/hostname > /dev/null

# Update /etc/hosts with the new hostname
echo -e "${GREEN}Updating /etc/hosts...${NC}"
current_hostname=$(hostname)
sudo sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts

# Confirm hostname update
echo -e "${GREEN}Hostname updated successfully to $new_hostname.${NC}"
echo -e "${GREEN}Verifying the new hostname:${NC}"
hostnamectl

# ----------------------------
# Install VM Tools
# ----------------------------

echo -e "${YELLOW}Installing Open VM Tools...${NC}"
sudo apt-get update -y
sudo apt-get install -y open-vm-tools

# ----------------------------
# Set DNS Servers (Cloudflare and Google)
# ----------------------------

echo -e "${YELLOW}Backing up and updating DNS servers in /etc/systemd/resolved.conf...${NC}"
sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.backup
sudo sed -i '/^DNS=/d' /etc/systemd/resolved.conf
sudo sed -i '/^FallbackDNS=/d' /etc/systemd/resolved.conf

sudo tee -a /etc/systemd/resolved.conf > /dev/null <<EOL
DNS=1.1.1.1 8.8.8.8
FallbackDNS=1.0.0.1 8.8.4.4
EOL

sudo systemctl restart systemd-resolved
echo -e "${GREEN}DNS configuration updated successfully.${NC}"
resolvectl status

# ----------------------------
# Install and Configure Mailutils and Postfix
# ----------------------------

echo -e "${YELLOW}Updating package list and installing mailutils and postfix...${NC}"
sudo apt update -y
sudo apt install -y unattended-upgrades apt-listchanges mailutils postfix || { echo -e "${RED}Package installation failed. Exiting.${NC}"; exit 1; }

# Set domain for email sender address
echo -e "${YELLOW}Enter the domain to use for email sender address (e.g., example.com):${NC}"
read -p "> " email_domain

# Function to configure and restart Postfix
configure_postfix() {
    echo -e "${YELLOW}Configuring Postfix for direct send using an SMTP relay...${NC}"
    read -p "Enter the SMTP relay server (e.g., smtp-relay.example.com): " smtp_server
    read -p "Enter the SMTP relay port (e.g., 25): " smtp_port

    # Get the system hostname
    system_hostname=$(hostname)

    # Configure Postfix for direct send with the specified relay
    sudo tee /etc/postfix/main.cf > /dev/null <<EOL
relayhost = [$smtp_server]:$smtp_port
myhostname = $system_hostname
myorigin = $email_domain
smtp_tls_security_level = may
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
EOL

    # Restart Postfix to apply changes
    echo -e "${GREEN}Restarting Postfix to apply new relay settings...${NC}"
    sudo systemctl restart postfix
}

# Test email function
send_test_email() {
    read -p "Enter the email address to send a test email to: " test_email
    echo -e "${GREEN}Mailutils and Postfix direct send setup complete${NC}" | mail -s "Test Email" "$test_email" -a "From: ${system_hostname}@${email_domain}"
    echo -e "${YELLOW}A test email has been sent to $test_email.${NC}"
}

# Initial Postfix configuration
configure_postfix
send_test_email

# Prompt user to confirm receipt, with option to reconfigure if necessary
while true; do
    read -p "Please check your inbox and confirm if you received the test email (Y/N): " email_received
    if [[ "$email_received" =~ ^[yY]([eE][sS])?$ ]]; then
        echo -e "${GREEN}Email confirmed received. Postfix setup complete.${NC}"
        break
    elif [[ "$email_received" =~ ^[nN]([oO])?$ ]]; then
        echo -e "${RED}Email not received. Let's update the relay details and try again.${NC}"
        configure_postfix
        send_test_email
    else
        echo -e "${YELLOW}Invalid input. Please enter Y (yes) or N (no).${NC}"
    fi
done
echo -e "${GREEN}Postfix direct send setup complete.${NC}"

# ----------------------------
# Configure Unattended Upgrades
# ----------------------------

echo -e "${YELLOW}Configuring unattended-upgrades...${NC}"
sudo dpkg-reconfigure --priority=low unattended-upgrades

echo -e "${YELLOW}Setting up automatic updates...${NC}"
sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOL

echo -e "${YELLOW}Setting up email alerts for unattended upgrades...${NC}"
sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null <<EOL
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Mail "msanotifications@blackbirdit.com.au";
Unattended-Upgrade::MailReport "always";
Unattended-Upgrade::MailOnlyOnError "true";
Unattended-Upgrade::OnlyOnACPower "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Sender "$(hostname)";
EOL

echo -e "${YELLOW}Testing unattended-upgrades setup...${NC}"
sudo unattended-upgrades --dry-run --debug
echo -e "${GREEN}Automatic updates enabled, with email alerts configured.${NC}"

# ----------------------------
# Nmap & Openscap Installation
# ----------------------------

echo -e "${YELLOW}Installing nmap service...${NC}"
sudo apt-get install nmap -y
sudo apt install openscap-scanner
sudo apt install libopenscap8

# ----------------------------
# CyberCNS Probe Installation
# ----------------------------

echo -e "${YELLOW}Starting CyberCNS Probe installation...${NC}"
while true; do
    read -p "Please enter Company ID: " companyID
    read -p "Please enter Tenant ID: " tenantID

    read -p "You entered Company ID: $companyID and Tenant ID: $tenantID. Confirm? (Y/N): " confirm
    if [[ "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
        break
    else
        echo -e "${YELLOW}Please re-enter the Company ID and Tenant ID.${NC}"
    fi
done

# Download and install CyberCNS agent
echo -e "${YELLOW}Retrieving CyberCNS Linux agent download URL...${NC}"
linuxurl=$(curl -L -s -g "https://configuration.myconnectsecure.com/api/v4/configuration/agentlink?ostype=linux" | tr -d '"')
if [[ -z "$linuxurl" ]]; then
    echo -e "${RED}Failed to retrieve the agent link. Exiting.${NC}"
    exit 1
fi

echo -e "${YELLOW}Downloading CyberCNS agent...${NC}"
curl -k "$linuxurl" -o cybercnsagent_linux
chmod +x cybercnsagent_linux

echo -e "${YELLOW}Running the CyberCNS Probe installer...${NC}"
sudo ./cybercnsagent_linux -c "$companyID" -e "$tenantID" -j "2DdCvz91ijTjIZQcjpHFaoT1LIf_OMwApOrI_l4mrdnjR49WsQ1b2_Uy3a-W8latdMKfNnwHFGFAD5Vzvew0qViuYQQGOEnf6xGa2w" -i

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}CyberCNS Probe installed successfully.${NC}"
else
    echo -e "${RED}Installation failed. Please check the provided details and try again.${NC}"
fi
