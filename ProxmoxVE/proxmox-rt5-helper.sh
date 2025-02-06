#!/usr/bin/env bash

# Proxmox VE Helper Script to install Debian 12 LXC with Request Tracker 5 (RT5)

# Variables
CTID="1024"  # Change this to your desired CTID
HOSTNAME="rt5.lxc"
PASSWORD="tmpP@55#1488sm0k3"  # Change this to your desired root password
MEMORY="2048"  # Memory in MB
SWAP="4096"  # Swap in MB
DISK="32G"  # Disk size
CORES="2"  # Number of CPU cores
IP="10.0.10.24/24"  # Change this to your desired IP address
GATEWAY="10.0.10.254"  # Change this to your gateway
DNS="9.9.9.9"  # Change this to your DNS server
STORAGE="local-lvm"  # Change this to your storage

# Create the LXC container
pct create $CTID /var/lib/vz/template/cache/debian-12-standard_12.0-1_amd64.tar.zst \
  --hostname $HOSTNAME \
  --password $PASSWORD \
  --memory $MEMORY \
  --swap $SWAP \
  --storage $STORAGE \
  --disk $DISK \
  --cores $CORES \
  --net0 name=eth0,ip=$IP,gw=$GATEWAY,ip6=auto \
  --unprivileged 1 \
  --features nesting=1

# Start the container
pct start $CTID

# Wait for the container to start
sleep 10

# Install necessary packages
pct exec $CTID -- bash -c "apt-get update && apt-get install -y curl gnupg2 apt-transport-https"

# Add Request Tracker repository
pct exec $CTID -- bash -c "echo 'deb https://download.bestpractical.com/pub/debian/ bullseye main' > /etc/apt/sources.list.d/rt5.list"
pct exec $CTID -- bash -c "curl -L https://download.bestpractical.com/pub/debian/bestpractical.key | apt-key add -"

# Update and install RT5
pct exec $CTID -- bash -c "apt-get update && apt-get install -y rt5"

# Configure RT5
pct exec $CTID -- bash -c "rt-setup-database --action init --dba dba --dba-password 'yourdbapassword'"
pct exec $CTID -- bash -c "rt-setup-database --action insert --datadir /usr/share/request-tracker5"

# Restart Apache
pct exec $CTID -- bash -c "systemctl restart apache2"

# Output the IP address
echo "Request Tracker 5 has been installed successfully!"
echo "You can access RT5 at http://$IP"

# End of script
