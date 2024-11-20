#!/bin/bash
# Git Basics Script

# Initialize a new Git repository
git init

# Configure user information
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Clone a repository
git clone https://github.com/your-repo/example.git

# Stage and commit changes
git add .
git commit -m "Initial commit"

# Push changes to a remote repository
git push origin main

# Check the status of the repository
git status

# Pull the latest changes from the remote repository
git pull origin main
