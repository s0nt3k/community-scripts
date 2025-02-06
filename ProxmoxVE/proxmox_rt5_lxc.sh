#!/bin/bash

# Copyright (c) 2021-2025 s0nt3k
# Author: s0nt3k
# E-Mail: s0nt3k@protonmail.com
# License: MIT
# https://github.com/s0nt3k/community-scripts/blob/main/LICENSE
# Source: https://github.com/bestpractical/rt


# Configuration variables
CT_ID=1020  # Change this to your desired container ID
HOSTNAME="rt-5"
PASSWORD="rt5password"
DISK_SIZE="16GB"
MEMORY="2048"
SWAP="4096"
CPU_CORES="2"
BRIDGE="vmbr0"
IP="10.0.10.24/24"  # Change to your network settings
GATEWAY="10.0.10.254"

# Download Debian 12 template if not already available
if ! pveam list local | grep -q "debian-12"; then
    echo "Downloading Debian 12 LXC template..."
    pveam download local debian-12-standard_12.0-1_amd64.tar.zst
fi

# Create LXC container
pct create $CT_ID local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst \
    -hostname $HOSTNAME \
    -storage local-lvm \
    -memory $MEMORY \
    -net0 name=eth0,bridge=$BRIDGE,ip=dhcp \
    -rootfs $DISK_SIZE \
    -password $PASSWORD \
    -unprivileged 1 \
    -features nesting=1

# Start container
pct start $CT_ID
sleep 10  # Wait for container to initialize

# Install dependencies and RT5
pct exec $CT_ID -- bash -c "\
    apt update && apt install -y apache2 libapache2-mod-fcgid mariadb-server \ 
    request-tracker5 rt5-db-mysql openssh-server \
    && systemctl enable apache2 mariadb ssh \ 
    && systemctl start apache2 mariadb ssh \ 
    && rt-setup-database --action init --dba root --prompt-for-dba-password"

# Configure Apache
pct exec $CT_ID -- bash -c "\
    echo 'Include /etc/request-tracker5/apache2-fastcgi.conf' > /etc/apache2/sites-available/rt5.conf \
    && a2ensite rt5 \
    && a2enmod fcgid \
    && systemctl restart apache2"

# Enable SSH access with verbose logging
pct exec $CT_ID -- bash -c "\
    sed -i 's/#LogLevel INFO/LogLevel VERBOSE/' /etc/ssh/sshd_config \
    && systemctl restart ssh"

# Output info
echo "Request Tracker 5 LXC installed."
echo "Access RT5 at: http://$(pct exec $CT_ID -- hostname -I | awk '{print $1}')/rt"
echo "SSH access enabled. Use: ssh root@$(pct exec $CT_ID -- hostname -I | awk '{print $1}')"
