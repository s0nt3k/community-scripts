#!/usr/bin/env bash

# Copyright (c) 2021-2025 s0nt3k
# Author: s0nt3k
# E-Mail: s0nt3k@protonmail.com
# License: MIT
# 
# Source: https://github.com/bestpractical/rt


# Configuration variables
CT_ID=1020  # Change this to your desired container ID
HOSTNAME="rt-5"
PASSWORD="rt5password"
DISK_SIZE="32G"
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

# Create the container
echo "Creating LXC container..."
pct create $CT_ID local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst \
    -hostname $HOSTNAME \
    -password $PASSWORD \
    -storage local-lvm \
    -rootfs $DISK_SIZE \
    -memory $MEMORY \
    -swap $SWAP \
    -cores $CPU_CORES \
    -net0 name=eth0,bridge=$BRIDGE,ip=$IP,gw=$GATEWAY \
    -unprivileged 1 \
    -features nesting=1

# Start the container
echo "Starting LXC container..."
pct start $CT_ID

# Wait for the container to boot
sleep 10

# Run installation commands inside the container
echo "Installing Request Tracker 5 inside LXC..."
pct exec $CT_ID -- bash -c "
    apt update && apt upgrade -y
    apt install -y apache2 mariadb-server mariadb-client \
                   rt5 rt5-apache2 postfix 

    # Configure MariaDB
    mysql -uroot -e \"
    CREATE DATABASE rt5;
    CREATE USER 'rt_user'@'localhost' IDENTIFIED BY 'rt_pass';
    GRANT ALL PRIVILEGES ON rt5.* TO 'rt_user'@'localhost';
    FLUSH PRIVILEGES;\"

    # Configure RT5
    cp /etc/request-tracker5/RT_SiteConfig.pm /etc/request-tracker5/RT_SiteConfig.pm.bak
    echo '
    Set(\$DatabaseType, 'mysql');
    Set(\$DatabaseHost, 'localhost');
    Set(\$DatabasePort, '3306');
    Set(\$DatabaseUser, 'rt_user');
    Set(\$DatabasePassword, 'rt_pass');
    Set(\$DatabaseName, 'rt5');
    Set(\$WebDomain, \"$HOSTNAME\");
    Set(\$WebPort, 80);
    Set(\$WebPath, \"\");
    Set(\$CorrespondAddress, 'rt@example.com');
    Set(\$CommentAddress, 'rt-comment@example.com');
    ' > /etc/request-tracker5/RT_SiteConfig.pm

    # Initialize the RT database
    /usr/sbin/rt-setup-database --action create --dba root --prompt-for-dba-password

    # Enable RT5 in Apache
    a2enmod rewrite
    a2enmod fcgid
    a2ensite request-tracker5
    systemctl restart apache2

    # Set permissions
    chown -R www-data:www-data /var/log/request-tracker5/
    systemctl enable apache2 mariadb
"

echo "Request Tracker 5 installation completed. Access it at http://$IP"
