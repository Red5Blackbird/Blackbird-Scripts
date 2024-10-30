#!/bin/bash

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
read -p "Enter the new hostname: " new_hostname

# Validate input
if [[ -z "$new_hostname" ]]; then
    echo "Hostname cannot be empty. Exiting."
    exit 1
fi

# Set the hostname temporarily and update configuration files
echo "Setting temporary hostname to $new_hostname..."
sudo hostnamectl set-hostname "$new_hostname"

echo "Updating /etc/hostname with $new_hostname..."
echo "$new_hostname" | sudo tee /etc/hostname > /dev/null

# Update /etc/hosts with the new hostname
echo "Updating /etc/hosts..."
current_hostname=$(hostname)
sudo sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts

# Confirm hostname update
echo "Hostname updated successfully to $new_hostname."
echo "Verifying the new hostname:"
hostnamectl

# ----------------------------
# Install VM Tools
# ----------------------------

echo "Installing Open VM Tools..."
sudo apt-get update -y
sudo apt-get install -y open-vm-tools

# ----------------------------
# Set DNS Servers (Cloudflare and Google)
# ----------------------------

echo "Backing up and updating DNS servers in /etc/systemd/resolved.conf..."
sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.backup
sudo sed -i '/^DNS=/d' /etc/systemd/resolved.conf
sudo sed -i '/^FallbackDNS=/d' /etc/systemd/resolved.conf

sudo tee -a /etc/systemd/resolved.conf > /dev/null <<EOL
DNS=1.1.1.1 8.8.8.8
FallbackDNS=1.0.0.1 8.8.4.4
EOL

sudo systemctl restart systemd-resolved
echo "DNS configuration updated successfully."
resolvectl status

# ----------------------------
# Install and Configure Mailutils and Postfix
# ----------------------------

echo "Updating package list and installing mailutils and postfix..."
sudo apt update -y
sudo apt install -y unattended-upgrades apt-listchanges mailutils postfix || { echo "Package installation failed. Exiting."; exit 1; }

# Function to configure and restart Postfix
configure_postfix() {
    echo "Configuring Postfix for direct send using an SMTP relay..."
    read -p "Enter the SMTP relay server (e.g., smtp-relay.example.com): " smtp_server
    read -p "Enter the SMTP relay port (e.g., 25): " smtp_port

    # Configure Postfix for direct send with the specified relay
    sudo tee /etc/postfix/main.cf > /dev/null <<EOL
relayhost = [$smtp_server]:$smtp_port
smtp_tls_security_level = may
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
EOL

    # Restart Postfix to apply changes
    echo "Restarting Postfix to apply new relay settings..."
    sudo systemctl restart postfix
}

# Test email function
send_test_email() {
    read -p "Enter the email address to send a test email to: " test_email
    echo "Mailutils and Postfix direct send setup complete" | mail -s "Test Email" "$test_email"
    echo "A test email has been sent to $test_email."
}

# Initial Postfix configuration
configure_postfix
send_test_email

# Prompt user to confirm receipt, with option to reconfigure if necessary
while true; do
    read -p "Please check your inbox and confirm if you received the test email (Y/N): " email_received
    if [[ "$email_received" =~ ^[yY]([eE][sS])?$ ]]; then
        echo "Email confirmed received. Postfix setup complete."
        break
    elif [[ "$email_received" =~ ^[nN]([oO])?$ ]]; then
        echo "Email not received. Let's update the relay details and try again."
        configure_postfix
        send_test_email
    else
        echo "Invalid input. Please enter Y (yes) or N (no)."
    fi
done
echo "Postfix direct send setup complete."

# ----------------------------
# Configure Unattended Upgrades
# ----------------------------

echo "Configuring unattended-upgrades..."
sudo dpkg-reconfigure --priority=low unattended-upgrades

echo "Setting up automatic updates..."
sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOL

echo "Setting up email alerts for unattended upgrades..."
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
Unattended-Upgrade::Sender "$(hostname)"
EOL

echo "Testing unattended-upgrades setup..."
sudo unattended-upgrades --dry-run --debug
echo "Automatic updates enabled, with email alerts configured."

# ----------------------------
# Nmap Installation
# ----------------------------

echo "Installing nmap service..."
sudo apt-get install nmap -y


# ----------------------------
# CyberCNS Probe Installation
# ----------------------------

echo "Starting CyberCNS Probe installation..."
while true; do
    read -p "Please enter Company ID: " companyID
    read -p "Please enter Tenant ID: " tenantID

    read -p "You entered Company ID: $companyID and Tenant ID: $tenantID. Confirm? (Y/N): " confirm
    if [[ "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
        break
    else
        echo "Please re-enter the Company ID and Tenant ID."
    fi
done

# Download and install CyberCNS agent
echo "Retrieving CyberCNS Linux agent download URL..."
linuxurl=$(curl -L -s -g "https://configuration.myconnectsecure.com/api/v4/configuration/agentlink?ostype=linux" | tr -d '"')
if [[ -z "$linuxurl" ]]; then
    echo "Failed to retrieve the agent link. Exiting."
    exit 1
fi

echo "Downloading CyberCNS agent..."
curl -k "$linuxurl" -o cybercnsagent_linux
chmod +x cybercnsagent_linux

echo "Running the CyberCNS Probe installer..."
sudo ./cybercnsagent_linux -c "$companyID" -e "$tenantID" -j "2DdCvz91ijTjIZQcjpHFaoT1LIf_OMwApOrI_l4mrdnjR49WsQ1b2_Uy3a-W8latdMKfNnwHFGFAD5Vzvew0qViuYQQGOEnf6xGa2w" -i

if [[ $? -eq 0 ]]; then
    echo "CyberCNS Probe installed successfully."
else
    echo "Installation failed. Please check the provided details and try again."
fi
