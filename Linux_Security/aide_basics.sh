#!/bin/bash
# Script to Install and Use AIDE (Advanced Intrusion Detection Environment)

# Install AIDE
sudo dnf install -y aide

# Initialize the AIDE Database
sudo aide --init

# Move the AIDE Database to the Active Location
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# Perform a System Integrity Check
sudo aide --check

# Update the AIDE Database
sudo aide --update
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# Set Up a Cron Job for Daily AIDE Checks
echo "0 3 * * * root /usr/sbin/aide --check" | sudo tee -a /etc/crontab

# Verify AIDE Configuration
sudo aide --config-check
