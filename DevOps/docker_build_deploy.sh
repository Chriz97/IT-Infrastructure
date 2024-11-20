#!/bin/bash
# Docker Build and Deploy Script

# Build the Docker image
docker build -t your-username/your-app:latest .

# Push the image to Docker Hub
docker login
docker push your-username/your-app:latest

# Run the container locally
docker run -d -p 8080:80 your-username/your-app:latest
