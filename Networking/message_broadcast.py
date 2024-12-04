import socket

# Broadcast Message Script
#This script sends a broadcast message over a specified UDP port.

message = "This is a broadcast message"
broadcast_address = "192.168.0.255"  # Your broadcast address
port = 13000

# Create a UDP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

# Send the broadcast message
sock.sendto(message.encode(), (broadcast_address, port))
sock.close()

print(f"Message sent to {broadcast_address}:{port}")
