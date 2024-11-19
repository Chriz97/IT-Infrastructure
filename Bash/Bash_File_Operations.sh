#!/bin/bash
# Example of Bash File Operations

file="example.txt"

# Create a file and write to it
echo "Creating a file and writing to it..."
echo "This is a sample file." > "$file"

# Append to the file
echo "Appending more content..."
echo "Additional line of text." >> "$file"

# Read the file
echo "Reading the file:"
cat "$file"

# Check if the file exists
if [ -e "$file" ]; then
    echo "The file exists."
else
    echo "The file does not exist."
fi
