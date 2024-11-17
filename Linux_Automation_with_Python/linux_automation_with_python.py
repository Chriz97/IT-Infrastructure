# Linux Automation with Python Script
import os
import subprocess
import psutil  # Install with `pip install psutil`

# Task 1: Create a new directory and file
directory = "/tmp/automation_example"
file_path = os.path.join(directory, "example.txt")

os.makedirs(directory, exist_ok=True)
with open(file_path, "w") as file:
    file.write("This file was created by a Python automation script.\n")

print(f"Directory and file created at: {file_path}")

# Task 2: Create a C program (test.c) with a for loop
c_program_path = os.path.join(directory, "test.c")
with open(c_program_path, "w") as c_file:
    c_file.write("""\
#include <stdio.h>

int main() {
    for (int i = 0; i < 50; i++) {
        printf("Iteration %d\\n", i);
    }
    return 0;
}
""")

print(f"C program created at: {c_program_path}")

# Task 3: Compile the C program using gcc
compiled_program_path = os.path.join(directory, "test_program")
try:
    subprocess.run(["gcc", "-o", compiled_program_path, c_program_path], check=True)
    print(f"Compiled program created at: {compiled_program_path}")
except subprocess.CalledProcessError:
    print("Error: Failed to compile the C program. Ensure gcc is installed.")

# Task 4: List running processes
print("\nListing running processes:")
for proc in psutil.process_iter(['pid', 'name', 'username']):
    print(f"PID: {proc.info['pid']}, Name: {proc.info['name']}, User: {proc.info['username']}")

# Task 5: Check disk usage
print("\nChecking disk usage:")
disk_usage = psutil.disk_usage('/')
print(f"Total: {disk_usage.total / (1024**3):.2f} GB")
print(f"Used: {disk_usage.used / (1024**3):.2f} GB")
print(f"Free: {disk_usage.free / (1024**3):.2f} GB")

# Task 6: Run a network diagnostic command (ping)
host = "google.com"
print(f"\nPinging {host}...")
result = subprocess.run(["ping", "-c", "4", host], stdout=subprocess.PIPE, text=True)
print(result.stdout)

# Automating a system update (Fedora/RHEL-based systems)
print("\nAutomating system update (command: sudo dnf update -y)")
# Uncomment the following line to actually run the update (requires root privileges):
# subprocess.run(["sudo", "dnf", "update", "-y"], check=True)
