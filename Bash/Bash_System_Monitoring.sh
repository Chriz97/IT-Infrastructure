#!/bin/bash
# Simple System Monitoring Script

# Check CPU usage
echo "CPU Usage:"
top -b -n1 | grep "Cpu(s)" | awk '{print $2 + $4 "%"}'

# Check memory usage
echo "Memory Usage:"
free -h

# Check disk space
echo "Disk Space:"
df -h
