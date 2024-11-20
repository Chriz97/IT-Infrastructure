#!/bin/bash
# Script to remove users from a Linux system

# Define the list of users to remove
users=("Hanna" "Anna-Lena" "Lina" "Aurea")

# Loop through each user and remove them
for user in "${users[@]}"; do
    echo "Removing user: $user"

    # Sanitize username (replace invalid characters for Linux usernames)
    sanitized_user=$(echo "$user" | tr -c 'a-zA-Z0-9' '_' | sed 's/_$//')

    # Check if the user exists
    if id "$sanitized_user" &>/dev/null; then
        # Remove the user and their home directory
        sudo userdel -r "$sanitized_user"
        echo "User $sanitized_user removed successfully."
    else
        echo "User $sanitized_user does not exist. Skipping..."
    fi
done
