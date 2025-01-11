# Systemctl Custom Service Integration Script
# All commands and configurations were tested on Fedora 41 Workstation

# Step 1: Create your custom script
# Example: A Python TCP server script. Save it to /usr/local/bin/tcp_server.py
nano /usr/local/bin/tcp_server.py

# Example script content:
# --------------------------------------------------
# import socket
#
# HOST = "0.0.0.0"
# PORT = 13000
#
# sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
# sock.bind((HOST, PORT))
# sock.listen(5)
# print(f"Server listening on {HOST}:{PORT}")
#
# while True:
#     conn, addr = sock.accept()
#     print(f"Connection established with {addr}")
#     data = conn.recv(1024).decode()
#     if data:
#         print(f"Received: {data}")
#     conn.sendall("Message received!".encode())
#     conn.close()
# --------------------------------------------------

# Make the script executable:
chmod +x /usr/local/bin/tcp_server.py

# Step 2: Create a systemd service file for the custom script
nano /etc/systemd/system/tcp_server.service

# Example service file content:
# --------------------------------------------------
# [Unit]
# Description=TCP Server
# After=network.target
#
# [Service]
# ExecStart=/usr/bin/python3 /usr/local/bin/tcp_server.py
# Restart=on-failure
# User=chriz
# Group=chriz
# WorkingDirectory=/usr/local/bin
# StandardOutput=journal
# StandardError=journal
#
# [Install]
# WantedBy=multi-user.target
# --------------------------------------------------

# Reload systemd to apply the new service file.
systemctl daemon-reload

# Enable the service to start automatically at boot.
systemctl enable tcp_server.service

# Start the service immediately.
systemctl start tcp_server.service

# Step 3: Check the service status
# View the current status of the service.
systemctl status tcp_server.service

# If the service fails, use journalctl to debug.
journalctl -u tcp_server.service

# Step 4: Test the script functionality
# Connect to the server using a TCP client (e.g., netcat or telnet).
# Example: Use netcat to send a message to the server.
echo "Hello, Server!" | nc 127.0.0.1 13000

# Check the logs for the server to see the received message.
cat /path/to/your/log/file # Example: /home/chriz/Scripts/tcp.logs

# Additional Notes:
# - Replace "chriz" with the appropriate user on your system.
# - Use `systemctl stop tcp_server.service` to stop the service.
# - Use `systemctl disable tcp_server.service` to prevent it from starting at boot.
