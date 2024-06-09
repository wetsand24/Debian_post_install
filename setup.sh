#!/bin/bash

# Ensuring the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Interactive script to setup a Debian server
echo "Starting setup..."

# Detecting active network interface
primary_interface=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
echo "Detected primary network interface: $primary_interface"

# 1. Add user to sudo group
read -p "Enter the username to add to sudo group (default: krangwala): " username
username=${username:-krangwala}

if id "$username" &>/dev/null; then
    usermod -aG sudo $username
    echo "$username added to sudo group."
else
    echo "User $username does not exist. Skipping add to sudo group."
fi

# 2. Enable SSH access
echo "Enabling SSH..."
apt-get update
apt-get install -y openssh-server
systemctl enable ssh
systemctl start ssh
echo "SSH has been enabled and started."

# 3. Setup static IP and disable DHCP
echo "Configuring static IP and disabling DHCP for $primary_interface..."
read -p "Enter the static IP address (default: 10.37.0.27/20): " ip
ip=${ip:-10.37.0.27/20}

read -p "Enter the gateway (default: 10.37.0.1): " gateway
gateway=${gateway:-10.37.0.1}

read -p "Enter primary DNS (default: 10.37.0.25): " dns1
dns1=${dns1:-10.37.0.25}

read -p "Enter secondary DNS (default: 1.1.1.1): " dns2
dns2=${dns2:-1.1.1.1}

# Removing any DHCP configurations and applying static settings
echo "Updating network settings..."
cat > /etc/network/interfaces.d/$primary_interface <<EOF
# This file is managed by a setup script
auto $primary_interface
iface $primary_interface inet static
    address $ip
    netmask 255.255.240.0
    gateway $gateway
    dns-nameservers $dns1 $dns2
EOF

# Remove potential conflicting entries from /etc/network/interfaces
sed -i "/iface $primary_interface inet dhcp/d" /etc/network/interfaces
sed -i "/allow-hotplug $primary_interface/d" /etc/network/interfaces

ifdown $primary_interface; ifup $primary_interface
echo "Network configuration updated. DHCP disabled, static IP set."

# 4. Change hostname
echo "Changing hostname..."
read -p "Enter new hostname (default: zabbix): " new_hostname
new_hostname=${new_hostname:-zabbix}

echo $new_hostname > /etc/hostname
sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$new_hostname/g" /etc/hosts
hostnamectl set-hostname $new_hostname
echo "Hostname changed to $new_hostname."

echo "Setup completed."
