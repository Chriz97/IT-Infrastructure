#!/bin/bash
# Script to Install, Configure, and Test Tuned on CentOS Stream 9
# This script demonstrates how to manage and create custom profiles using Tuned.

# What is Tuned?
# Tuned is a Linux daemon used to optimize system performance by applying predefined or custom tuning profiles.
# It dynamically adjusts system parameters like CPU governor, disk I/O scheduler, and kernel settings
# to match workload requirements, improving efficiency and performance.

# Step 1: Check the Status of Tuned
# Verify if the Tuned service is running.
sudo systemctl status tuned

# Step 2: Start the Tuned Service
# If Tuned is not running, start the service.
sudo systemctl start tuned

# Step 3: Verify the Active Profile
# Display the currently active Tuned profile.
tuned-adm active

# Step 4: List Available Profiles
# View all available Tuned profiles on the system.
tuned-adm list

# Step 5: Apply a Predefined Profile
# Set the "network-latency" profile for low-latency network operations.
tuned-adm profile network-latency

# Step 6: Verify the Active Profile Again
# Ensure the "network-latency" profile is now active.
tuned-adm active

# Step 7: List Additional Available Tuned Packages
# Check for additional Tuned profiles that can be installed.
dnf list available *tuned*

# Step 8: Install Additional Tuned Profiles
# Example: Install the Microsoft SQL Server Tuned profile package.
sudo dnf install tuned-profiles-mssql.noarch

# Step 9: Check the Recommended Profile
# Get the profile recommended by Tuned for the system's workload.
tuned-adm recommend 
# The output here is for example: virtual-guest when using a Virtual Machine

# Step 10: View and Modify the Active Profile
# Open the active profile configuration file for manual editing (Example).
sudo nano /etc/tuned/active_profile

# Step 11: Locate Tuned Configuration Files
# List all files installed by the Tuned package.
rpm -ql tuned

# Step 12: Explore Predefined Profiles
# Example: View the configuration of the "throughput-performance" profile.
cat /usr/lib/tuned/throughput-performance/tuned.conf

# Step 13: Create a Custom Tuned Profile
# Example: Create a custom profile named "awesome-virt-db-profile."
sudo mkdir /etc/tuned/awesome-virt-db-profile
cd /etc/tuned/awesome-virt-db-profile
sudo nano tuned.conf

# Example Tuned Configuration: tuned.conf
# This configuration optimizes a virtual guest environment for database workloads.
sudo tee /etc/tuned/awesome-virt-db-profile/tuned.conf << EOF
[main]
summary = A virtual-guest based profile that changes the disk scheduler and adjusts some sysctls for databases
include=virtual-guest

[disk]
devices=nvme0n1
elevator=mq-deadline

[sysctl]
vm.swappiness=10
vm.dirty_background_ratio = 3
vm.dirty_ratio = 40
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
EOF

# Step 14: Apply the Custom Profile
# Activate the custom profile "awesome-virt-db-profile."
tuned-adm profile awesome-virt-db-profile

# Step 15: Verify Disk Scheduler and System Parameters
# Check the active disk scheduler for the specified device.
cat /sys/block/nvme0n1/queue/scheduler

# Verify the current swappiness value.
cat /proc/sys/vm/swappiness

# Step 16: Revert to a Default Profile
# Revert back to the "virtual-guest" profile.
tuned-adm profile virtual-guest

# Verify the changes again.
cat /proc/sys/vm/swappiness
cat /sys/block/nvme0n1/queue/scheduler
