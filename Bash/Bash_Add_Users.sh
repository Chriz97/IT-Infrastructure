#!/bin/bash
# Script to add users to a Linux system

# Define the list of users
users=("Hanna" "Anna-Lena" "Lina" "Aurea")

# Loop through each user and add them to the system
for user in "${users[@]}"; do
    echo "Adding user: $user"

    # Replace spaces or special characters with underscores for username compatibility
    sanitized_user=$(echo "$user" | tr -c 'a-zA-Z0-9' '_' | sed 's/_$//')

    # Check if the user already exists
    if id "$sanitized_user" &>/dev/null; then
        echo "User $sanitized_user already exists. Skipping..."
    else
        # Add the user
        sudo useradd -m -s /bin/bash "$sanitized_user"
        echo "User $sanitized_user added successfully."
    fi
done

echo "All users processed."

