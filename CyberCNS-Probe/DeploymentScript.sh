#!/bin/bash

# Color codes
GREEN='\e[0;32m'
YELLOW='\e[1;33m'
RED='\e[0;31m'
NC='\e[0m' # No Color

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
        printf "${RED}Hostname cannot be empty. Exiting.${NC}\n"
        exit 1
    fi

    printf "${GREEN}Setting hostname to $new_hostname...${NC}\n"
    sudo hostnamectl set-hostname "$new_hostname"
    echo "$new_hostname" | sudo tee /etc/hostname > /dev/null
    sudo sed -i "s/$(hostname)/$new_hostname/g" /etc/hosts
    printf "${GREEN}Hostname updated successfully.${NC}\n"
}

# Install required packages
install_packages() {
    printf "${YELLOW}Installing Open VM Tools and other utilities...${NC}\n"
    sudo apt-get update -y
    sudo apt-get install -y open-vm-tools unattended-upgrades apt-listchanges mailutils postfix nmap libopenscap8 || { printf "${RED}Package installation failed. Exiting.${NC}\n"; exit 1; }
}

# Configure DNS servers
configure_dns() {
    printf "${YELLOW}Configuring DNS servers...${NC}\n"
    sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.backup
    sudo sed -i '/^DNS=/d' /etc/systemd/resolved.conf
    sudo sed -i '/^FallbackDNS=/d' /etc/systemd/resolved.conf

    sudo tee -a /etc/systemd/resolved.conf > /dev/null <<EOL
DNS=1.1.1.1 8.8.8.8
FallbackDNS=1.0.0.1 8.8.4.4
EOL

    sudo systemctl restart systemd-resolved
    printf "${GREEN}DNS configuration updated successfully.${NC}\n"
}

# Configure and test Postfix
configure_postfix() {
    printf "${YELLOW}Enter email domain for sending email (e.g., example.com):${NC}\n"
    read -p "> " email_domain
    printf "${YELLOW}Enter SMTP relay server (e.g., smtp-relay.example.com):${NC}\n"
    read -p "> " smtp_server
    printf "${YELLOW}Enter SMTP relay port (e.g., 25):${NC}\n"
    read -p "> " smtp_port

    sudo tee /etc/postfix/main.cf > /dev/null <<EOL
relayhost = [$smtp_server]:$smtp_port
myhostname = $(hostname)
myorigin = $email_domain
smtp_tls_security_level = may
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
EOL

    printf "${GREEN}Restarting Postfix to apply changes...${NC}\n"
    sudo systemctl restart postfix

    printf "${YELLOW}Enter email address to send a test email to:${NC}\n"
    read -p "> " test_email
    echo "Mailutils and Postfix setup complete" | mail -s "Test Email" "$test_email" -a "From: $(hostname)@$email_domain"
    printf "${YELLOW}Test email sent to $test_email. Please verify.${NC}\n"
}

# Configure unattended upgrades with email alerts
configure_upgrades() {
    printf "${YELLOW}Enter notifications email address for alerts:${NC}\n"
    read -p "> " email_alert
    printf "${YELLOW}Configuring unattended-upgrades...${NC}\n"
    
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

    printf "${GREEN}Unattended upgrades with email alerts configured.${NC}\n"
}

# Install CyberCNS Probe
install_cybercns_probe() {
    while true; do
        printf "${YELLOW}Enter Company ID:${NC}\n"
        read -p "> " companyID
        printf "${YELLOW}Enter Tenant ID:${NC}\n"
        read -p "> " tenantID

        printf "${YELLOW}Confirm details - Company ID: $companyID, Tenant ID: $tenantID (Y/N):${NC}\n"
        read -p "> " confirm
        if [[ "$confirm" =~ ^[yY]$ ]]; then
            break
        else
            printf "${YELLOW}Please re-enter the Company ID and Tenant ID.${NC}\n"
        fi
    done

    linuxurl=$(curl -L -s -g "https://configuration.myconnectsecure.com/api/v4/configuration/agentlink?ostype=linux" | tr -d '"')
    if [[ -z "$linuxurl" ]]; then
        printf "${RED}Failed to retrieve agent link. Exiting.${NC}\n"
        exit 1
    fi

    printf "${YELLOW}Downloading CyberCNS agent...${NC}\n"
    curl -k "$linuxurl" -o cybercnsagent_linux
    chmod +x cybercnsagent_linux

    printf "${YELLOW}Running CyberCNS Probe installer...${NC}\n"
    sudo ./cybercnsagent_linux -c "$companyID" -e "$tenantID" -j "2DdCvz91ijTjIZQcjpHFaoT1LIf_OMwApOrI_l4mrdnjR49WsQ1b2_Uy3a-W8latdMKfNnwHFGFAD5Vzvew0qViuYQQGOEnf6xGa2w" -i
}

# Deploy Sophos Agent
deploy_sophos_agent() {
    printf "${YELLOW}Enter the Sophos agent download URL:${NC}\n"
    read -p "> " url
    if [[ -z "$url" ]]; then
        printf "${RED}URL cannot be empty. Skipping.${NC}\n"
        return
    fi

    filename=$(basename "$url")
    printf "${YELLOW}Downloading Sophos agent...${NC}\n"
    curl -L -o "$filename" "$url"
    chmod +x "$filename"

    printf "${YELLOW}Run '$filename' now? (y/n):${NC}\n"
    read -p "> " run_now
    [[ "$run_now" =~ ^[yY]$ ]] && ./"$filename"
}

# Update ServerAdmin password
update_password() {
    printf "${YELLOW}Enter new password for 'serveradmin':${NC}\n"
    read -sp "> " new_password
    echo
    printf "${YELLOW}Confirm new password:${NC}\n"
    read -sp "> " confirm_password
    echo

    if [[ "$new_password" != "$confirm_password" ]]; then
        printf "${RED}Passwords do not match. Exiting.${NC}\n"
        exit 1
    fi

    echo "serveradmin:$new_password" | sudo chpasswd
    printf "${GREEN}Password for 'serveradmin' successfully reset.${NC}\n"
}

# ----------------------------
# Main Script Execution
# ----------------------------

printf "${GREEN}Starting CyberCNS Deployment Script...${NC}\n"

set_hostname
configure_dns
install_packages
configure_postfix
configure_upgrades
install_cybercns_probe
deploy_sophos_agent
update_password

printf "${GREEN}CyberCNS Deployment Script completed successfully!${NC}\n"
