"""
TCP Client Script
-----------------
This script sends a TCP message to a specific server and port. It's useful for testing TCP servers 
and can be customized for various use cases. By default, it sends a message "This is a TCP message" 
to a server at IP address 192.168.58.130 on port 13000.

Command-line arguments:
- `--message`: The message to send (default: "This is a TCP message").
- `--host`: The destination server's IP address (default: 192.168.58.130).
- `--port`: The destination port to connect to (default: 13000).

Usage:
1. Start a TCP server on the target machine (e.g., using a simple Python TCP server script).
2. Run this script on the client machine to send the message.
3. The server will receive and optionally respond to the message.

Example:
    python tcp_client.py --message "Hello, Server!" --host 192.168.1.10 --port 12345

"""

import socket
import argparse

# Parse command-line arguments
parser = argparse.ArgumentParser(description="Send a TCP message to a specific host and port.")
parser.add_argument("--message", type=str, default="This is a TCP message", help="Message to send")
parser.add_argument("--host", type=str, default="192.168.58.130", help="Destination host address")
parser.add_argument("--port", type=int, default=13000, help="Port to use for sending the message")
args = parser.parse_args()

# Extract arguments
message = args.message  # The message to send
host = args.host        # The destination host (server)
port = args.port        # The destination port

# Create a TCP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  # AF_INET = IPv4, SOCK_STREAM = TCP

try:
    # Connect to the server
    print(f"Connecting to {host}:{port}...")
    sock.connect((host, port))  # Establish a TCP connection to the server

    # Send the message
    print(f"Sending message: {message}")
    sock.sendall(message.encode())  # Send the message as bytes

    print(f"Message sent to {host}:{port}")
finally:
    # Close the socket connection
    print("Closing connection.")
    sock.close()
