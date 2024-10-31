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
# Function Definitions
# ----------------------------

# Set new hostname
set_hostname() {
    echo -e "${YELLOW}Enter the new hostname:${NC}"
    read -p "> " new_hostname
    if [[ -z "$new_hostname" ]]; then
        echo -e "${RED}Hostname cannot be empty. Exiting.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Setting hostname to $new_hostname...${NC}"
    sudo hostnamectl set-hostname "$new_hostname"
    echo "$new_hostname" | sudo tee /etc/hostname > /dev/null
    sudo sed -i "s/$(hostname)/$new_hostname/g" /etc/hosts
    echo -e "${GREEN}Hostname updated successfully.${NC}"
}

# Install required packages
install_packages() {
    echo -e "${YELLOW}Installing Open VM Tools and other utilities...${NC}"
    sudo apt-get update -y
    sudo apt-get install -y open-vm-tools unattended-upgrades apt-listchanges mailutils postfix nmap libopenscap8 || { echo -e "${RED}Package installation failed. Exiting.${NC}"; exit 1; }
}

# Configure DNS servers
configure_dns() {
    echo -e "${YELLOW}Configuring DNS servers...${NC}"
    sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.backup
    sudo sed -i '/^DNS=/d' /etc/systemd/resolved.conf
    sudo sed -i '/^FallbackDNS=/d' /etc/systemd/resolved.conf

    sudo tee -a /etc/systemd/resolved.conf > /dev/null <<EOL
DNS=1.1.1.1 8.8.8.8
FallbackDNS=1.0.0.1 8.8.4.4
EOL

    sudo systemctl restart systemd-resolved
    echo -e "${GREEN}DNS configuration updated successfully.${NC}"
}

# Configure and test Postfix
configure_postfix() {
    read -p "${YELLOW}Enter email domain for sending email (e.g., example.com):${NC} " email_domain
    read -p "${YELLOW}Enter SMTP relay server (e.g., smtp-relay.example.com):${NC} " smtp_server
    read -p "${YELLOW}Enter SMTP relay port (e.g., 25):${NC} " smtp_port

    sudo tee /etc/postfix/main.cf > /dev/null <<EOL
relayhost = [$smtp_server]:$smtp_port
myhostname = $(hostname)
myorigin = $email_domain
smtp_tls_security_level = may
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
EOL

    echo -e "${GREEN}Restarting Postfix to apply changes...${NC}"
    sudo systemctl restart postfix

    read -p "${YELLOW}Enter email address to send a test email to:${NC} " test_email
    echo "Mailutils and Postfix setup complete" | mail -s "Test Email" "$test_email" -a "From: $(hostname)@$email_domain"
    echo -e "${YELLOW}Test email sent to $test_email. Please verify.${NC}"
}

# Configure unattended upgrades with email alerts
configure_upgrades() {
    read -p "${YELLOW}Enter notifications email address for alerts:${NC} " email_alert
    echo -e "${YELLOW}Configuring unattended-upgrades...${NC}"
    
    sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOL

    sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null <<EOL
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Mail "$email_alert";
Unattended-Upgrade::MailReport "always";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOL

    echo -e "${GREEN}Unattended upgrades with email alerts configured.${NC}"
}

# Install CyberCNS Probe
install_cybercns_probe() {
    while true; do
        read -p "${YELLOW}Enter Company ID:${NC} " companyID
        read -p "${YELLOW}Enter Tenant ID:${NC} " tenantID

        read -p "${YELLOW}Confirm details - Company ID: $companyID, Tenant ID: $tenantID (Y/N):${NC} " confirm
        if [[ "$confirm" =~ ^[yY]$ ]]; then
            break
        else
            echo -e "${YELLOW}Please re-enter the Company ID and Tenant ID.${NC}"
        fi
    done

    linuxurl=$(curl -L -s -g "https://configuration.myconnectsecure.com/api/v4/configuration/agentlink?ostype=linux" | tr -d '"')
    if [[ -z "$linuxurl" ]]; then
        echo -e "${RED}Failed to retrieve agent link. Exiting.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Downloading CyberCNS agent...${NC}"
    curl -k "$linuxurl" -o cybercnsagent_linux
    chmod +x cybercnsagent_linux

    echo -e "${YELLOW}Running CyberCNS Probe installer...${NC}"
    sudo ./cybercnsagent_linux -c "$companyID" -e "$tenantID" -j "2DdCvz91ijTjIZQcjpHFaoT1LIf_OMwApOrI_l4mrdnjR49WsQ1b2_Uy3a-W8latdMKfNnwHFGFAD5Vzvew0qViuYQQGOEnf6xGa2w" -i
}

# Deploy Sophos Agent
deploy_sophos_agent() {
    read -p "${YELLOW}Enter the Sophos agent download URL:${NC} " url
    if [[ -z "$url" ]]; then
        echo -e "${RED}URL cannot be empty. Skipping.${NC}"
        return
    fi

    filename=$(basename "$url")
    echo -e "${YELLOW}Downloading Sophos agent...${NC}"
    curl -L -o "$filename" "$url"
    chmod +x "$filename"

    read -p "${YELLOW}Run '$filename' now? (y/n):${NC} " run_now
    [[ "$run_now" =~ ^[yY]$ ]] && ./"$filename"
}

# Update ServerAdmin password
update_password() {
    read -sp "${YELLOW}Enter new password for 'serveradmin':${NC} " new_password
    echo
    read -sp "${YELLOW}Confirm new password:${NC} " confirm_password
    echo

    if [[ "$new_password" != "$confirm_password" ]]; then
        echo -e "${RED}Passwords do not match. Exiting.${NC}"
        exit 1
    fi

    echo "serveradmin:$new_password" | sudo chpasswd
    echo -e "${GREEN}Password for 'serveradmin' successfully reset.${NC}"
}

# ----------------------------
# Main Script Execution
# ----------------------------

echo -e "${GREEN}Starting CyberCNS Deployment Script...${NC}"

set_hostname
install_packages
configure_dns
configure_postfix
configure_upgrades
install_cybercns_probe
deploy_sophos_agent
update_password

echo -e "${GREEN}CyberCNS Deployment Script completed successfully!${NC}"
