#!/usr/bin/env python3
#
# This script sends an ARP request on the local network to discover the MAC address
# associated with a given IP address. ARP (Address Resolution Protocol) is used to map
# IP addresses to MAC addresses within the same LAN segment.
#
# How it works:
# - We craft an ARP request: "Who has TARGET_IP? Tell me."
# - We send it as a broadcast on the LAN, so all devices receive it.
# - The device with the requested IP responds with its MAC address.
#
# Requirements:
# - Run with root privileges (e.g., "sudo python3 arp_lookup.py") since raw packet
#   operations require elevated permissions.
# - Ensure scapy is installed: "pip install scapy"
#
# Usage:
# - Set TARGET_IP to the IP of the target host you want to discover.
# - Run the script. If the host is on the same LAN and alive, you'll see its MAC address.

from scapy.all import ARP, Ether, srp

def main():
    TARGET_IP = "192.168.0.12"  # Replace with the Windows client's IP

    # Create an ARP request packet: "Who has TARGET_IP? Tell ME"
    arp_request = ARP(pdst=TARGET_IP)

    # Ethernet frame for broadcast: send ARP request to all hosts on the LAN
    broadcast = Ether(dst="ff:ff:ff:ff:ff:ff")

    # Combine the Ethernet frame and ARP request into one packet
    arp_request_broadcast = broadcast / arp_request

    print(f"Sending ARP request for {TARGET_IP}...")
    # srp() sends and receives packets at layer 2
    answered, unanswered = srp(arp_request_broadcast, timeout=3, verbose=0)

    # Check if we got a response
    if answered:
        # Each answer is a pair of (sent_packet, received_packet)
        for sent, received in answered:
            # The received packet includes an ARP response with the MAC address
            print(f"IP {received.psrc} is at MAC {received.hwsrc}")
    else:
        print(f"No response for {TARGET_IP}. Is the host online and on the same LAN?")

if __name__ == "__main__":
    main()
