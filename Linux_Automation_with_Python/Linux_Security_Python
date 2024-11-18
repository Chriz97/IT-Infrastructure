# Linux Security with Python Script
import os
import subprocess
import pwd
import grp
from pathlib import Path

# Task 1: Scan open ports using netstat
print("\nScanning open ports:")
result = subprocess.run(["netstat", "-tuln"], stdout=subprocess.PIPE, text=True)
print(result.stdout)

# Task 2: Check file permissions for sensitive files
print("\nChecking file permissions for sensitive files:")
files_to_check = ["/etc/passwd", "/etc/shadow", "/etc/hosts"]
for file in files_to_check:
    file_info = Path(file)
    if file_info.exists():
        permissions = oct(file_info.stat().st_mode)[-3:]
        owner = pwd.getpwuid(file_info.stat().st_uid).pw_name
        group = grp.getgrgid(file_info.stat().st_gid).gr_name
        print(f"{file}: Permissions: {permissions}, Owner: {owner}, Group: {group}")
    else:
        print(f"{file} does not exist.")

# Task 3: Monitor failed login attempts
print("\nMonitoring failed login attempts (last 10 lines from /var/log/auth.log):")
try:
    result = subprocess.run(["tail", "-n", "10", "/var/log/auth.log"], stdout=subprocess.PIPE, text=True)
    print(result.stdout)
except FileNotFoundError:
    print("Log file /var/log/auth.log not found. This script requires a Linux system with auth.log.")

# Task 4: Search for SUID files (potential security risks)
print("\nSearching for SUID files:")
result = subprocess.run(["find", "/", "-perm", "-4000", "-type", "f", "-ls"], stdout=subprocess.PIPE, text=True, stderr=subprocess.DEVNULL)
print(result.stdout)

# Task 5: Check for root login attempts
print("\nChecking for root login attempts in auth.log:")
try:
    result = subprocess.run(["grep", "root", "/var/log/auth.log"], stdout=subprocess.PIPE, text=True)
    print(result.stdout)
except FileNotFoundError:
    print("Log file /var/log/auth.log not found. This script requires a Linux system with auth.log.")
