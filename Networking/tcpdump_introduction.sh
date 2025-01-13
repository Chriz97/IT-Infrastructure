# Linux Networking Introduction Script
# All commands were tested on Amazon Linux 2.

# tcpdump is a powerful packet capture tool used for network troubleshooting and traffic analysis.
# Below are examples of how to use tcpdump for capturing traffic on specific ports, protocols, and services.

# 1. Capture all traffic on a specific interface.
# Example: Capture traffic on the "eth0" interface.
sudo tcpdump -i eth0

# 2. Capture traffic on a specific port.
# Example: Capture traffic on port 80 (HTTP).
sudo tcpdump -i eth0 port 80

# 3. Capture traffic excluding a specific port.
# Example: Exclude SSH traffic (port 22) while capturing all other traffic.
sudo tcpdump -i eth0 not port 22

# 4. Capture only TCP traffic.
# Example: Capture TCP packets on the "eth0" interface.
sudo tcpdump -i eth0 tcp

# 5. Capture only ICMP traffic.
# Example: Useful for monitoring ping requests and replies.
sudo tcpdump -i eth0 icmp

# 6. Capture UDP traffic.
# Example: Capture all UDP traffic on the "eth0" interface.
sudo tcpdump -i eth0 udp

# 7. Write captured packets to a file.
# Example: Save captured packets to a file named "capture.pcap" for later analysis.
sudo tcpdump -i eth0 -w capture.pcap

# 8. Read a previously captured file.
# Example: Analyze packets from "capture.pcap".
sudo tcpdump -r capture.pcap

# 9. Capture traffic from a specific IP address.
# Example: Capture all packets from the source IP 192.168.1.100.
sudo tcpdump -i eth0 src 192.168.1.100

# 10. Capture traffic to a specific IP address.
# Example: Capture all packets destined for the IP 192.168.1.200.
sudo tcpdump -i eth0 dst 192.168.1.200

# 11. Capture traffic on a range of ports.
# Example: Capture traffic on ports 8000 to 8100.
sudo tcpdump -i eth0 portrange 8000-8100

# 12. Display packets with a timestamp.
# Example: Add human-readable timestamps to packet capture output.
sudo tcpdump -i eth0 -tt

# 13. Limit the number of packets captured.
# Example: Capture only the first 10 packets.
sudo tcpdump -i eth0 -c 10

# 14. Filter traffic using logical operators (and, or, not).
# Example: Capture TCP packets from 192.168.1.100 and exclude port 22.
sudo tcpdump -i eth0 tcp and src 192.168.1.100 and not port 22

# 15. Capture DNS traffic.
# Example: Monitor DNS queries and responses (UDP on port 53).
sudo tcpdump -i eth0 port 53

# 16. Display packets in verbose or detailed format.
# Example: Show packet details with verbose output (-v) or very verbose (-vv).
sudo tcpdump -i eth0 -vv

# 17. Capture only SYN packets.
# Example: Useful for analyzing new TCP connections.
sudo tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0'

# 18. Filter by specific hostnames.
# Example: Capture traffic to and from example.com (requires DNS resolution).
sudo tcpdump -i eth0 host example.com

# Notes:
# - Use the `-n` flag to prevent DNS resolution of IP addresses.
# - Use the `-nn` flag to prevent both DNS resolution and service name resolution for ports.
# Example: sudo tcpdump -i eth0 -nn port 80

# This script demonstrates how to use tcpdump effectively for various network analysis scenarios.
