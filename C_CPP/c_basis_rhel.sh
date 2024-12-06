#!/bin/bash
# Script: Get Started with C/C++ on Red Hat Enterprise Linux
# This script sets up a development environment for C/C++ on RHEL,
# compiles, and runs a basic C program.

# Step 1: Install Development Tools
# Ensure GCC and essential development tools are installed.
sudo dnf group install -y "Development Tools"

# Step 2: Create a Hello World C Program
# Define the C code for the program.

vim helloworld.c # You can also use Nano or every other text editor.

# The following is a sample C script:

#include <stdio.h>

void for_loop();

int main() {
    printf("Hello, World!\n");
    for_loop();
    return 0;
}

void for_loop() {
    for (int i = 0; i <= 10000; i = i + 100) {
        printf("i = %d\n", i);
    }
}

# Step 3: Compile the C Program
# Use GCC to compile the program into an executable.
gcc helloworld.c -o helloworld

# Step 4: Make the Executable File Executable
# Ensure the compiled program has execute permissions.
chmod +x helloworld

# Step 5: Run the Compiled Program
# Execute the program and display its output.
./helloworld
