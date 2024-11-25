#!/bin/bash
# Manage Sudo Privileges with Visudo Script
# This script demonstrates best practices for managing sudo privileges using visudo.

# 1. Backup the sudoers file
sudo cp /etc/sudoers /etc/sudoers.bak

# 2. Open the sudoers file safely using visudo
# The visudo command checks for syntax errors to prevent issues.
sudo visudo

# Note: The script pauses here for you to edit the file interactively.

# 3. Add User-Specific Sudo Privileges
# Example: Add a rule to allow a user (e.g., "john") to run all commands without a password.
echo "john ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/john

# 4. Add Group-Specific Sudo Privileges
# Example: Allow the "admins" group to execute commands without a password.
echo "%admins ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/admins

# 5. Test Sudo Privileges
# Example: Test the sudo access for user "john" (requires running this script as "john").
sudo -l -U john
