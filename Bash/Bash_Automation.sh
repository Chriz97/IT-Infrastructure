#!/bin/bash
# Automate backup of /var/log directory

backup_dir="/backup"
log_dir="/var/log"
timestamp=$(date +%Y%m%d)

# Ensure the backup directory exists
mkdir -p "$backup_dir"

# Compress and backup logs
tar -czvf "$backup_dir/logs_$timestamp.tar.gz" "$log_dir"
echo "Backup completed: $backup_dir/logs_$timestamp.tar.gz"
