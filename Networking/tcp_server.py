"""
TCP Server Script
-----------------
This script implements a simple TCP server that listens on a specified port for incoming connections.
When a client connects, the server receives the message, prints it to the console, and optionally
sends a response back to the client.

## Features:
- Listens for incoming TCP connections on a specified port.
- Handles multiple connection requests (up to 5 queued by default).
- Prints received messages to the console.
- Sends a confirmation message back to the client ("Message received!").

## Default Settings:
- Host: 0.0.0.0 (listen on all available network interfaces)
- Port: 13000

## Usage:
1. Run this script to start the server:
    ```bash
    python tcp_server.py
    ```

2. Use a TCP client (e.g., another Python script or a tool like `telnet` or `nc`) to connect to the server and send messages.

3. The server will display the received messages and optionally respond to the client.

Example:
    Run this script on one machine (or a VM), and connect using a client script:
    ```bash
    python tcp_client.py --message "Hello, Server!" --host <server-ip> --port 13000
    ```

"""

import socket

# Server configuration
HOST = "0.0.0.0"  # Listen on all available network interfaces
PORT = 13000      # Port to listen on

# Create a TCP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  # AF_INET = IPv4, SOCK_STREAM = TCP
sock.bind((HOST, PORT))  # Bind the socket to the host and port

# Listen for incoming connections
sock.listen(5)  # Allow up to 5 simultaneous connection requests
print(f"Server listening on {HOST}:{PORT}")

try:
    while True:
        # Accept a new connection
        conn, addr = sock.accept()  # Blocks until a client connects
        print(f"Connection established with {addr}")

        # Receive data from the client
        data = conn.recv(1024).decode()  # Receive up to 1024 bytes
        if data:
            print(f"Received message: {data}")

        # Optionally send a response back to the client
        conn.sendall("Message received!".encode())

        # Close the connection with the client
        conn.close()
except KeyboardInterrupt:
    # Gracefully handle termination (Ctrl+C)
    print("\nShutting down the server.")
finally:
    # Ensure the socket is properly closed
    sock.close()
