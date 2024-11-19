#!/bin/bash
# Example of Bash Debugging

# Enable debugging
set -x

# Simple math operation
num1=10
num2=5
sum=$((num1 + num2))
echo "Sum: $sum"

# Disable debugging
set +x

# Trap errors
trap 'echo "An error occurred on line $LINENO"; exit 1' ERR

# Deliberate error
ls non_existent_file
