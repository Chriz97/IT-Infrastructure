#!/bin/bash
# Example of Bash Networking

# Ping a host
host="google.com"
echo "Pinging $host..."
ping -c 4 $host

# Fetch HTTP headers
url="https://www.kernel.org"
echo "Fetching HTTP headers for $url..."
curl -I "$url"
