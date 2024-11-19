#!/bin/bash
# Example of Bash Loops

# For loop
echo "For loop: Iterating over files in the current directory"
for file in *; do
    echo "$file"
done

# While loop
echo "While loop: Counting down from 5"
count=5
while [ $count -gt 0 ]; do
    echo "$count"
    count=$((count - 1))
done

# Until loop
echo "Until loop: Incrementing until a condition is met"
count=1
until [ $count -ge 5 ]; do
    echo "$count"
    count=$((count + 1))
done
