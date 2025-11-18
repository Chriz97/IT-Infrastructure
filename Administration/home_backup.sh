#!/bin/bash

# Home Directory Backup Script
# Backs up home directory to /mnt/development/Backup_Home

# Configuration
SOURCE_DIR="$HOME"
BACKUP_DIR="/mnt/development/Backup_Home"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="home_backup_${TIMESTAMP}.tar.gz"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Home Directory Backup Script"
echo "========================================="
echo "Source: $SOURCE_DIR"
echo "Destination: $BACKUP_PATH"
echo ""

# Create backup directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${YELLOW}Backup directory does not exist. Creating it...${NC}"
    mkdir -p "$BACKUP_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to create backup directory${NC}"
        exit 1
    fi
    echo -e "${GREEN}Backup directory created successfully${NC}"
fi

# Check if destination is writable
if [ ! -w "$BACKUP_DIR" ]; then
    echo -e "${RED}Error: Backup directory is not writable${NC}"
    exit 1
fi

# Exclude common directories to reduce backup size
# Modify this list based on your needs
EXCLUDE_DIRS=(
    ".cache"
    ".local/share/Trash"
    ".mozilla/firefox/*/Cache"
    ".thumbnails"
    "Downloads"
    ".npm"
    ".cargo"
    "node_modules"
)

# Build exclude parameters
EXCLUDE_PARAMS=""
for dir in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_PARAMS="$EXCLUDE_PARAMS --exclude=$dir"
done

# Perform backup
echo -e "${YELLOW}Starting backup...${NC}"
echo "This may take a while depending on the size of your home directory."
echo ""

tar -czf "$BACKUP_PATH" $EXCLUDE_PARAMS -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" 2>&1 | while read line; do
    echo "$line"
done

# Check if backup was successful
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}Backup completed successfully!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo "Backup file: $BACKUP_PATH"
    echo "Backup size: $BACKUP_SIZE"
    echo ""

    # Optional: Remove old backups (keep last 5)
    echo "Checking for old backups..."
    BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/home_backup_*.tar.gz 2>/dev/null | wc -l)
    if [ $BACKUP_COUNT -gt 5 ]; then
        echo "Removing old backups (keeping last 5)..."
        ls -1t "$BACKUP_DIR"/home_backup_*.tar.gz | tail -n +6 | xargs rm -f
        echo -e "${GREEN}Old backups removed${NC}"
    fi
else
    echo ""
    echo -e "${RED}=========================================${NC}"
    echo -e "${RED}Backup failed!${NC}"
    echo -e "${RED}=========================================${NC}"
    exit 1
fi
